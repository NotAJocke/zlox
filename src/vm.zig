const std = @import("std");

const modchunk = @import("chunk.zig");
const Chunk = modchunk.Chunk;
const OpCode = modchunk.OpCode;
const Value = @import("value.zig").Value;
const compile = @import("compiler.zig").compile;

pub const VmError = error{
    Compile,
    Runtime,
};

const STACK_MAX = 256;
pub const VM = struct {
    chunk: *Chunk = undefined,
    ip: [*]u8 = undefined,
    debug: bool = false,
    stack: [STACK_MAX]Value = [_]Value{Value{ .numberVal = 0 }} ** STACK_MAX,
    stackTop: [*]Value = undefined,

    const Self = @This();

    pub fn resetStack(self: *Self) void {
        self.stackTop = self.stack[0..].ptr;
    }

    pub fn pushStack(self: *Self, value: Value) void {
        self.stackTop[0] = value;
        self.stackTop += 1;
    }

    pub fn popStack(self: *Self) Value {
        self.stackTop -= 1;
        return self.stackTop[0];
    }

    pub fn interpret(self: *Self, gpa: std.mem.Allocator, source: []const u8) VmError!void {
        self.resetStack();
        var chunk: Chunk = .init(gpa);
        defer chunk.deinit();

        try compile(source, &chunk, self.debug);

        self.chunk = &chunk;
        self.ip = chunk.code.items.ptr;
        return self.run();
    }

    fn read_byte(self: *Self) u8 {
        const byte = self.ip[0];
        self.ip += 1;
        return byte;
    }

    fn binaryOp(self: *Self, op: OpCode) !void {
        const x = self.popStack();
        const y = self.popStack();

        if (x != .numberVal or y != .numberVal) {
            self.runtimeError("Operands must be numbers.", .{});
            return VmError.Runtime;
        }

        const b = x.numberVal;
        const a = y.numberVal;

        switch (op) {
            .ADD => self.pushStack(Value{ .numberVal = a + b }),
            .SUBTRACT => self.pushStack(Value{ .numberVal = a - b }),
            .MULTIPLY => self.pushStack(Value{ .numberVal = a * b }),
            .DIVIDE => self.pushStack(Value{ .numberVal = a / b }),
            .LESS => self.pushStack(Value{ .boolVal = b > a }),
            .GREATER => self.pushStack(Value{ .boolVal = b < a }),
            else => unreachable,
        }
    }

    fn peek(self: *Self, distance: usize) Value {
        const index = @intFromPtr(self.stackTop) - 1 - distance;
        return self.stackTop[index];
    }

    fn runtimeError(self: *Self, comptime format: []const u8, comptime args: anytype) void {
        std.debug.print(format, args);
        std.debug.print("\n", .{});

        const ip_addr = @intFromPtr(self.ip);
        const code_start = @intFromPtr(self.chunk.code.items.ptr);

        const instruction = (ip_addr - code_start) - 1;
        const line = self.chunk.getLine(instruction);

        std.debug.print("[line {d}] in script\n", .{line});
        self.resetStack();
    }

    fn isFalsey(value: Value) bool {
        switch (value) {
            .nil => return true,
            .boolVal => |val| return !val,
            else => return false,
        }
    }

    fn run(self: *Self) VmError!void {
        if (self.debug) {
            std.debug.print("== exec ==", .{});
        }

        while (true) {
            if (self.debug) {
                std.debug.print("          ", .{});
                var slot = self.stack[0..].ptr;
                while (@intFromPtr(slot) < @intFromPtr(self.stackTop)) : (slot += 1) {
                    std.debug.print("[ '{any}' ] ", .{slot[0]});
                }
                std.debug.print("\n", .{});

                _ = self.chunk.disassembleInstruction(self.ip - self.chunk.code.items.ptr);
            }

            const byte = self.read_byte();
            const instruction: OpCode = @enumFromInt(byte);

            switch (instruction) {
                .CONSTANT => {
                    const constant = self.chunk.constants.items[self.read_byte()];
                    self.pushStack(constant);
                },
                .TRUE => self.pushStack(Value{ .boolVal = true }),
                .FALSE => self.pushStack(Value{ .boolVal = false }),
                .EQUAL => {
                    const b = self.popStack();
                    const a = self.popStack();
                    self.pushStack(Value{ .boolVal = b.equals(a) });
                },
                .NIL => self.pushStack(Value.nil),
                .ADD, .SUBTRACT, .MULTIPLY, .DIVIDE, .GREATER, .LESS => try self.binaryOp(instruction),
                .NOT => self.pushStack(Value{ .boolVal = isFalsey(self.popStack()) }),
                .NEGATE => {
                    switch (self.peek(0)) {
                        .numberVal => |value| {
                            _ = self.popStack();
                            self.pushStack(Value{ .numberVal = -value });
                        },
                        else => {
                            self.runtimeError("Operand must be a number", .{});
                            return VmError.Runtime;
                        },
                    }
                },
                .RETURN => {
                    std.debug.print("'{s}'\n", .{self.popStack().toString()});
                    return;
                },
            }
        }
    }
};
