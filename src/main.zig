const std = @import("std");
const Io = std.Io;

const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;

    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            _ = gpa.detectLeaks();
        }
    }

    const allocator = gpa.allocator();

    var c: Chunk = .empty;
    defer c.deinit(allocator);

    const constant = try c.addConstant(allocator, 1.2);
    try c.writeOp(allocator, OpCode.CONSTANT, 123);
    try c.write(allocator, @intCast(constant), 123);

    try c.writeOp(allocator, OpCode.RETURN, 123);

    c.disassemble("test chunk");
}
