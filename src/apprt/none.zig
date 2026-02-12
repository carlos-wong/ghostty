const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const internal_os = @import("../os/main.zig");
const apprt = @import("../apprt.zig");
pub const resourcesDir = internal_os.resourcesDir;

pub const App = struct {
    /// On macOS, use a URL scheme to communicate with the running Ghostty
    /// instance. On other platforms, return false.
    pub fn performIpc(
        alloc: Allocator,
        _: apprt.ipc.Target,
        comptime action: apprt.ipc.Action.Key,
        value: apprt.ipc.Action.Value(action),
    ) !bool {
        if (comptime builtin.target.os.tag != .macos) return false;

        const action_name = switch (action) {
            .new_window => "new-window",
            .new_tab => "new-tab",
        };

        // Build the URL: ghostty://<action>?e=<url-encoded-args>
        var url: std.ArrayList(u8) = .empty;
        defer url.deinit(alloc);

        try url.appendSlice(alloc, "ghostty://");
        try url.appendSlice(alloc, action_name);

        if (value.arguments) |arguments| {
            if (arguments.len > 0) {
                try url.appendSlice(alloc, "?e=");
                for (arguments, 0..) |arg, i| {
                    if (i > 0) try url.appendSlice(alloc, "+");
                    try uriEncodeAppend(alloc, &url, arg);
                }
            }
        }

        try url.append(alloc, 0);
        const url_z: [:0]const u8 = url.items[0 .. url.items.len - 1 :0];

        // Use macOS `open` command to open the URL
        const result = std.process.Child.run(.{
            .allocator = alloc,
            .argv = &.{ "open", url_z },
        }) catch return false;
        defer alloc.free(result.stdout);
        defer alloc.free(result.stderr);

        return result.term == .Exited and result.term.Exited == 0;
    }

    /// Percent-encode a string for use in a URL query parameter.
    fn uriEncodeAppend(alloc: Allocator, list: *std.ArrayList(u8), input: []const u8) !void {
        for (input) |c| {
            if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
                try list.append(alloc, c);
            } else {
                try list.appendSlice(alloc, &.{ '%', hexDigit(@truncate(c >> 4)), hexDigit(@truncate(c & 0x0f)) });
            }
        }
    }

    fn hexDigit(v: u4) u8 {
        return "0123456789ABCDEF"[v];
    }
};
pub const Surface = struct {};
