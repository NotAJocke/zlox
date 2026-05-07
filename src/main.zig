const std = @import("std");
const Io = std.Io;

const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;

const VM = @import("vm.zig").VM;

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

    var constant = try c.addConstant(allocator, 1.2);
    try c.write(allocator, .CONSTANT, 123);
    try c.writeConstant(allocator, @intCast(constant), 123);

    constant = try c.addConstant(allocator, 3.4);
    try c.write(allocator, .CONSTANT, 123);
    try c.writeConstant(allocator, @intCast(constant), 123);

    try c.write(allocator, .ADD, 123);

    constant = try c.addConstant(allocator, 5.6);
    try c.write(allocator, .CONSTANT, 123);
    try c.writeConstant(allocator, @intCast(constant), 123);

    try c.write(allocator, .DIVIDE, 123);
    try c.write(allocator, .NEGATE, 123);

    try c.write(allocator, .RETURN, 123);

    // c.disassemble("test chunk");

    std.debug.print("\n== Execution ==\n", .{});

    var vm = VM{ .debug = true };

    try vm.interpret(&c);
}
