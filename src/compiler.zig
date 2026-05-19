const std = @import("std");

const scannerMod = @import("scanner.zig");
const chunkMod = @import("chunk.zig");

const Scanner = scannerMod.Scanner;
const TokenType = scannerMod.TokenType;
const Token = scannerMod.Token;
const Chunk = chunkMod.Chunk;
const OpCode = chunkMod.OpCode;
const Value = @import("value.zig").Value;
const VmError = @import("vm.zig").VmError;

pub fn compile(source: []const u8, chunk: *Chunk, debug: bool) VmError!void {
    var scanner: Scanner = .init(source);
    var parser: Parser = .init(&scanner, chunk);

    parser.advance();
    parser.expression();
    parser.consume(.EOF, "Expect end of expression.");

    try endCompiler(&parser, debug);

    if (parser.hadError) {
        return VmError.Compile;
    }
}

fn endCompiler(parser: *Parser, debug: bool) !void {
    parser.emitReturn();

    if (debug and !parser.hadError) {
        parser.currentChunk.disassemble("code");
    }
}

const Precedence = enum {
    NONE,
    ASSIGNMENT, // =
    OR, // or
    AND, // and
    EQUALITY, // == !=
    COMPARISON, // < > <= >=
    TERM, // + -
    FACTOR, // * /
    UNARY, // ! -
    CALL, // . ()
    PRIMARY,
};

const ParseFn = *const fn (self: *Parser) void;
const ParseRule = struct {
    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precedence,

    pub fn get(ttype: TokenType) *const ParseRule {
        return &Parser.rules[@intCast(@intFromEnum(ttype))];
    }
};

const Parser = struct {
    current: Token,
    previous: Token,
    hadError: bool,
    panicMode: bool,
    scanner: *Scanner,
    currentChunk: *Chunk,

    const Self = @This();

    const rules = init_rules: {
        var table = [_]ParseRule{.{ .prefix = null, .infix = null, .precedence = .NONE }} ** (@typeInfo(TokenType).@"enum".fields.len + 1);

        table[@intFromEnum(TokenType.LEFT_PAREN)] = .{ .prefix = grouping, .infix = null, .precedence = .NONE };
        table[@intFromEnum(TokenType.MINUS)] = .{ .prefix = unary, .infix = binary, .precedence = .TERM };
        table[@intFromEnum(TokenType.PLUS)] = .{ .prefix = null, .infix = binary, .precedence = .TERM };
        table[@intFromEnum(TokenType.SLASH)] = .{ .prefix = null, .infix = binary, .precedence = .FACTOR };
        table[@intFromEnum(TokenType.STAR)] = .{ .prefix = null, .infix = binary, .precedence = .FACTOR };
        table[@intFromEnum(TokenType.NUMBER)] = .{ .prefix = number, .infix = null, .precedence = .NONE };

        break :init_rules table;
    };

    pub fn init(scanner: *Scanner, chunk: *Chunk) Self {
        return Self{
            .current = undefined,
            .previous = undefined,
            .hadError = false,
            .panicMode = false,
            .scanner = scanner,
            .currentChunk = chunk,
        };
    }

    pub fn advance(self: *Self) void {
        self.previous = self.current;

        while (true) {
            self.current = self.scanner.scanToken();
            if (self.current.type != .ERROR) break;

            self.errorAtCurrent(self.current.start[0..@intCast(self.current.length)]);
        }
    }

    pub fn errorAtCurrent(self: *Self, message: []const u8) void {
        self.errorAt(&self.current, message);
    }

    pub fn errorr(self: *Self, message: []const u8) void {
        self.errorAt(&self.previous, message);
    }

    pub fn errorAt(self: *Self, token: *Token, message: []const u8) void {
        if (self.panicMode) return;
        self.panicMode = true;

        std.debug.print("[line {d}] Error", .{token.line});

        if (token.type == .EOF) {
            std.debug.print(" at end ", .{});
        } else if (token.type == .ERROR) {} else {
            std.debug.print(" at '{s}'", .{token.start[0..@intCast(token.length)]});
        }

        std.debug.print(": {s}\n", .{message});
        self.hadError = true;
    }

    pub fn consume(self: *Self, ttype: TokenType, message: []const u8) void {
        if (self.current.type == ttype) {
            self.advance();
            return;
        }

        self.errorAtCurrent(message);
    }

    pub fn emitByte(self: *Self, byte: u8) void {
        self.currentChunk.writeConstant(byte, @intCast(self.previous.line));
    }

    pub fn emitByteOp(self: *Self, op: OpCode) void {
        return self.emitByte(@intFromEnum(op));
    }

    pub fn emitBytes(self: *Self, b1: u8, b2: u8) void {
        self.currentChunk.writeConstant(b1, @intCast(self.previous.line));
        self.currentChunk.writeConstant(b2, @intCast(self.previous.line));
    }

    pub fn emitReturn(self: *Self) void {
        self.emitByte(@intFromEnum(OpCode.RETURN));
    }

    fn emitConstant(self: *Self, value: Value) void {
        self.emitBytes(@intFromEnum(OpCode.CONSTANT), self.makeConstant(value));
    }

    fn makeConstant(self: *Self, value: Value) u8 {
        const constant = self.currentChunk.addConstant(value);

        if (constant > std.math.maxInt(u8)) {
            self.errorr("Too many constants in one chunk.");
            return 0;
        }

        return @intCast(constant);
    }

    fn number(self: *Self) void {
        const value = std.fmt.parseFloat(f32, self.previous.start[0..@intCast(self.previous.length)]) catch {
            self.errorr("Couldn't parse number.");
            return;
        };
        self.emitConstant(Value{ .numberVal = value });
    }

    fn grouping(self: *Self) void {
        self.expression();
        self.consume(.RIGHT_PAREN, "Expect ')' after expression");
    }

    fn unary(self: *Self) void {
        const opType = self.previous.type;

        self.parsePrecedence(.UNARY);

        switch (opType) {
            .MINUS => self.emitByteOp(OpCode.NEGATE),
            else => unreachable,
        }
    }

    fn binary(self: *Self) void {
        const opType = self.previous.type;
        const rule = ParseRule.get(opType);
        self.parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

        switch (opType) {
            .PLUS => self.emitByteOp(OpCode.ADD),
            .MINUS => self.emitByteOp(OpCode.SUBTRACT),
            .STAR => self.emitByteOp(OpCode.MULTIPLY),
            .SLASH => self.emitByteOp(OpCode.DIVIDE),
            else => unreachable,
        }
    }

    pub fn expression(self: *Self) void {
        self.parsePrecedence(.ASSIGNMENT);
    }

    fn parsePrecedence(self: *Self, precedence: Precedence) void {
        self.advance();
        const prefixRule = ParseRule.get(self.previous.type).prefix;

        if (prefixRule == null) {
            self.errorr("Expect expression.");
            return;
        }

        prefixRule.?(self);

        while (@intFromEnum(precedence) <= @intFromEnum(ParseRule.get(self.current.type).precedence)) {
            self.advance();
            const infix = ParseRule.get(self.previous.type).infix;
            if (infix) |i| {
                i(self);
            }
        }
    }
};
