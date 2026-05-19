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
    stack: [STACK_MAX]Value = [_]Value{0} ** STACK_MAX,
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

    fn binaryOp(self: *Self, op: OpCode) void {
        const b = self.popStack();
        const a = self.popStack();

        switch (op) {
            .ADD => self.pushStack(a + b),
            .SUBTRACT => self.pushStack(a - b),
            .MULTIPLY => self.pushStack(a * b),
            .DIVIDE => self.pushStack(a / b),
            else => unreachable,
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
                .ADD, .SUBTRACT, .MULTIPLY, .DIVIDE => self.binaryOp(instruction),
                .NEGATE => {
                    self.pushStack(-self.popStack());
                },
                .RETURN => {
                    std.debug.print("'{d}'\n", .{self.popStack()});
                    return;
                },
            }
        }
    }
};
