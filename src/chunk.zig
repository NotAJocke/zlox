const std = @import("std");

const Value = @import("value.zig").Value;

pub const OpCode = enum(u8) {
    CONSTANT,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    NEGATE,
    RETURN,
};

pub const Chunk = struct {
    code: std.ArrayList(u8),
    constants: std.ArrayList(Value),
    lines: std.ArrayList(struct { line: u32, repeat: u32 }),
    arena: std.heap.ArenaAllocator,

    const Self = @This();

    // pub const empty: Self = .{ .code = .empty, .constants = .empty, .lines = .empty };

    pub fn init(gpa: std.mem.Allocator) Self {
        return Self{ .code = .empty, .constants = .empty, .lines = .empty, .arena = std.heap.ArenaAllocator.init(gpa) };
    }

    pub fn deinit(self: *Self) void {
        // self.code.deinit(alloc);
        // self.constants.deinit(alloc);
        // self.lines.deinit(alloc);
        self.arena.deinit();
    }

    pub fn write(self: *Self, code: OpCode, line: u32) void {
        self.writeConstant(@intFromEnum(code), line);
    }

    pub fn writeConstant(self: *Self, constant: u8, line: u32) void {
        const allocator = self.arena.allocator();

        self.code.append(allocator, constant) catch @panic("Out of memory");

        if (self.lines.items.len > 0) {
            const last = &self.lines.items[self.lines.items.len - 1];

            if (last.line == line) {
                last.repeat += 1;
                return;
            }
        }

        self.lines.append(allocator, .{ .line = line, .repeat = 1 }) catch @panic("Out of memory");
    }

    pub fn getLine(self: *Self, code_index: usize) u32 {
        var index = code_index;

        for (self.lines.items) |compressed| {
            if (index < compressed.repeat) {
                return compressed.line;
            }

            index -= compressed.repeat;
        }

        unreachable;
    }

    pub fn addConstant(self: *Self, value: Value) usize {
        const index = self.constants.items.len;
        self.constants.append(self.arena.allocator(), value) catch @panic("Out of memory");
        return index;
    }

    pub fn disassemble(self: *Self, name: []const u8) void {
        std.debug.print("== {s} ==\n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) {
            offset = self.disassembleInstruction(offset);
        }
    }

    pub fn disassembleInstruction(self: *Self, offset: usize) usize {
        std.debug.print("{d:0>4} ", .{offset});

        if (offset > 0 and self.getLine(offset) == self.getLine(offset - 1)) {
            std.debug.print("   | ", .{});
        } else {
            std.debug.print("{d:>4} ", .{self.getLine(offset)});
        }

        const rawOp = self.code.items[offset];
        const op: OpCode = @enumFromInt(rawOp);

        switch (op) {
            .RETURN => {
                std.debug.print("{s}\n", .{"OP_RETURN"});
                return offset + 1;
            },
            .ADD => {
                std.debug.print("{s}\n", .{"OP_ADD"});
                return offset + 1;
            },
            .SUBTRACT => {
                std.debug.print("{s}\n", .{"OP_SUBTRACT"});
                return offset + 1;
            },
            .MULTIPLY => {
                std.debug.print("{s}\n", .{"OP_MULTIPLY"});
                return offset + 1;
            },
            .DIVIDE => {
                std.debug.print("{s}\n", .{"OP_DIVIDE"});
                return offset + 1;
            },
            .NEGATE => {
                std.debug.print("{s}\n", .{"OP_NEGATE"});
                return offset + 1;
            },
            .CONSTANT => {
                const constant = self.code.items[offset + 1];
                std.debug.print("{s:<16} {d:>4} '{any}'\n", .{ "OP_CONSTANT", constant, self.constants.items[constant] });
                return offset + 2;
            },
        }
    }
};
