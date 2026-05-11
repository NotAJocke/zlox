const std = @import("std");
const Io = std.Io;

const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;

const VM = @import("vm.zig").VM;

fn repl(io: std.Io) !void {
    var vm = VM{};

    const stdIn = std.Io.File.stdin();
    var buffer: [1024]u8 = undefined;
    var reader = stdIn.reader(io, &buffer);

    while (true) {
        std.debug.print("> ", .{});
        const data = reader.interface.takeDelimiterInclusive('\n') catch {
            std.debug.print("\n", .{});
            return;
        };

        try vm.interpret(data);
    }
}

fn runFile(io: std.Io, filename: [:0]const u8, allocator: std.mem.Allocator) !void {
    var vm = VM{};

    const cwd = std.Io.Dir.cwd();
    const content = try cwd.readFileAlloc(io, filename, allocator, Io.Limit.unlimited);

    try vm.interpret(content);
}

pub fn main(init: std.process.Init) !void {
    const arena_alloc = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena_alloc);

    if (args.len == 1) {
        try repl(init.io);
    } else if (args.len == 2) {
        try runFile(init.io, args[1], arena_alloc);
    } else {
        std.debug.print("Usage: zlox [path]\n", .{});
        std.process.exit(64);
    }
}
