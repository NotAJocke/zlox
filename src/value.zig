const std = @import("std");
// pub const Value = f32;

pub const Value = union(enum) {
    boolVal: bool,
    numberVal: f32,
    nil,

    pub fn toString(self: Value) []const u8 {
        switch (self) {
            .boolVal => |val| {
                if (val) {
                    return "true";
                } else {
                    return "false";
                }
            },
            .numberVal => |val| {
                var buf: [32]u8 = undefined;
                return std.fmt.bufPrint(&buf, "{d}", .{val}) catch unreachable;
            },
            .nil => return "nil",
        }
    }

    pub fn equals(self: Value, other: Value) bool {
        if (!std.mem.eql(u8, @tagName(self), @tagName(other))) return false;

        switch (self) {
            .boolVal => |val| {
                return val == other.boolVal;
            },
            .nil => return true,
            .numberVal => |val| {
                return val == other.numberVal;
            },
        }
    }
};
