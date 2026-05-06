const std = @import("std");

const Value = @import("value.zig").Value;

pub const OpCode = enum(u8) {
    CONSTANT,
    RETURN,
};

pub const Chunk = struct {
    code: std.ArrayList(u8),
    constants: std.ArrayList(Value),
    lines: std.ArrayList(u32),

    const Self = @This();

    pub const empty: Self = .{ .code = .empty, .constants = .empty, .lines = .empty };

    pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
        self.code.deinit(alloc);
        self.constants.deinit(alloc);
        self.lines.deinit(alloc);
    }

    pub fn write(self: *Self, alloc: std.mem.Allocator, code: u8, line: u32) !void {
        try self.code.append(alloc, code);
        try self.lines.append(alloc, line);
    }

    pub fn writeOp(self: *Self, alloc: std.mem.Allocator, code: OpCode, line: u32) !void {
        try self.write(alloc, @intFromEnum(code), line);
    }

    pub fn addConstant(self: *Self, alloc: std.mem.Allocator, value: Value) !usize {
        const index = self.constants.items.len;
        try self.constants.append(alloc, value);
        return index;
    }

    pub fn disassemble(self: *Self, name: []const u8) void {
        std.debug.print("== {s} ==\n", .{name});

        var offset: u8 = 0;
        while (offset < self.code.items.len) {
            std.debug.print("{d:0>4} ", .{offset});

            if (offset > 0 and self.lines.items[offset] == self.lines.items[offset - 1]) {
                std.debug.print("   | ", .{});
            } else {
                std.debug.print("{d:>4} ", .{self.lines.items[offset]});
            }

            const rawOp = self.code.items[offset];
            const op: OpCode = @enumFromInt(rawOp);

            switch (op) {
                .RETURN => {
                    std.debug.print("{s}\n", .{"OP_RETURN"});
                    offset += 1;
                },
                .CONSTANT => {
                    const constant = self.code.items[offset + 1];
                    std.debug.print("{s:<16} {d:>4} '{any}'\n", .{ "OP_CONSTANT", constant, self.constants.items[constant] });
                    offset += 2;
                },
            }
        }
    }

    // fn disassembleInstruction(self: *Self, )

};
