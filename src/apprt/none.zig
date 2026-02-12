const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const internal_os = @import("../os/main.zig");
const apprt = @import("../apprt.zig");
pub const resourcesDir = internal_os.resourcesDir;

pub const App = struct {
    /// On macOS, use a URL scheme to communicate with the running Ghostty
    /// instance. On other platforms, return false.
    ///
    /// The URL scheme works as follows:
    ///   ghostty://<action>[?e=<shell-quoted-command>&cwd=<directory>]
    ///
    /// When a command is specified via `e`, the macOS app starts a new tab
    /// with the user's default login shell first (so that profile/rc scripts
    /// run and PATH is set up), then sends the command as stdin input
    /// (initialInput). This matches Terminal.app and iTerm2 behavior.
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

        // Build the URL: ghostty://<action>?e=<shell-quoted-args>&cwd=<dir>
        var url: std.ArrayList(u8) = .empty;
        defer url.deinit(alloc);

        try url.appendSlice(alloc, "ghostty://");
        try url.appendSlice(alloc, action_name);

        var has_query = false;

        if (value.arguments) |arguments| {
            if (arguments.len > 0) {
                try url.appendSlice(alloc, "?e=");
                has_query = true;
                for (arguments, 0..) |arg, i| {
                    // Use %20 (not +) as separator because Swift's
                    // URLComponents follows RFC 3986 where + is literal,
                    // not a space.
                    if (i > 0) try url.appendSlice(alloc, "%20");
                    // Shell-quote each argument individually so that
                    // arguments with spaces or special characters are
                    // correctly interpreted by the shell on the receiving end.
                    try shellQuoteAndUriEncode(alloc, &url, arg);
                }
            }
        }

        if (value.cwd) |cwd| {
            if (cwd.len > 0) {
                try url.appendSlice(alloc, if (has_query) "&cwd=" else "?cwd=");
                try uriEncodeAppend(alloc, &url, cwd);
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

    /// Shell-quote an argument and URI-encode the result.
    ///
    /// If the argument contains no shell-unsafe characters, it is
    /// URI-encoded as-is. Otherwise it is wrapped in single quotes
    /// (with embedded single quotes escaped as '\'') and then
    /// URI-encoded. This is equivalent to Python's shlex.quote().
    fn shellQuoteAndUriEncode(alloc: Allocator, url: *std.ArrayList(u8), input: []const u8) !void {
        if (input.len == 0) {
            // Empty string needs to be quoted as '' for the shell
            try url.appendSlice(alloc, "''");
            return;
        }

        var needs_quote = false;
        for (input) |c| {
            if (!isShellSafe(c)) {
                needs_quote = true;
                break;
            }
        }

        if (!needs_quote) {
            try uriEncodeAppend(alloc, url, input);
            return;
        }

        // Build shell-quoted string, then URI-encode it.
        var quoted: std.ArrayList(u8) = .empty;
        defer quoted.deinit(alloc);

        try quoted.append(alloc, '\'');
        for (input) |c| {
            if (c == '\'') {
                // Escape single quote: end current quote, backslash-quote, start new quote
                try quoted.appendSlice(alloc, "'\\''");
            } else {
                try quoted.append(alloc, c);
            }
        }
        try quoted.append(alloc, '\'');

        try uriEncodeAppend(alloc, url, quoted.items);
    }

    /// Returns true if the character is safe to use unquoted in a shell argument.
    /// Matches Python's shlex.quote() safe character set.
    fn isShellSafe(c: u8) bool {
        return std.ascii.isAlphanumeric(c) or switch (c) {
            '-', '_', '.', '/', ':', '@', '%', '+', ',', '~' => true,
            else => false,
        };
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
