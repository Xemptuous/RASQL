const std = @import("std");
const FileHandle = @import("file.zig").FileHandle;
const Page = @import("page.zig").Page;
const PAGE_SIZE = @import("page.zig").PAGE_SIZE;

pub const PageWriter = struct {
    file: *FileHandle,
    page: *Page,
    offset: usize,

    pub fn init(file: *FileHandle, page: *Page) PageWriter {
        return PageWriter{ .file = file, .page = page, .offset = 0 };
    }

    fn ensureSpace(self: *PageWriter, needed: usize) !void {
        if (self.offset + needed > PAGE_SIZE) {
            try self.file.advanceAndWritePage(self.page, &self.offset);
        }
    }

    pub fn writeBytes(self: *PageWriter, data: []const u8) !void {
        try self.ensureSpace(data.len);
        std.mem.copyForwards(u8, self.page.data[self.offset..], data);
        self.offset += data.len;
    }

    pub fn writeU8(self: *PageWriter, val: u8) !void {
        try self.ensureSpace(1);
        self.page.data[self.offset] = val;
        self.offset += 1;
    }

    pub fn writeU32(self: *PageWriter, val: u32) !void {
        try self.ensureSpace(4);
        var buf: [4]u8 = .{0} ** 4;
        buf = @bitCast(val);
        @memcpy(self.page.data[self.offset .. self.offset + 4], &buf);
        self.offset += 4;
    }

    pub fn writeString(self: *PageWriter, val: []const u8) !void {
        const len: u32 = @intCast(val.len);
        try self.ensureSpace(4 + val.len);

        // write the length
        var lenbuf: [4]u8 = .{0} ** 4;
        lenbuf = @bitCast(len);
        @memcpy(self.page.data[self.offset .. self.offset + 4], &lenbuf);
        self.offset += 4;

        // write the string
        std.mem.copyForwards(u8, self.page.data[self.offset..][0..val.len], val);
        self.offset += val.len;
    }

    pub fn position(self: *PageWriter) usize {
        return self.offset;
    }
};
