const std = @import("std");
const FileHandle = @import("../page/file.zig").FileHandle;
const Page = @import("page.zig").Page;
const PAGE_SIZE = @import("page.zig").PAGE_SIZE;

pub const PageReader = struct {
    file: *FileHandle,
    page: *Page,
    offset: usize,

    pub fn init(file: *FileHandle, page: *Page) PageReader {
        return PageReader{
            .file = file,
            .page = page,
            .offset = 0,
        };
    }

    fn ensureAvailable(self: *PageReader, needed: usize) !void {
        if (self.offset + needed > PAGE_SIZE) {
            const overflow = self.offset + needed - PAGE_SIZE;
            const bytes_read = try self.file.getNextPage(self.page);

            if (bytes_read < PAGE_SIZE and overflow > bytes_read)
                return error.EndOfPage;

            self.offset = overflow;
        }
    }

    pub fn readU8(self: *PageReader) !u8 {
        try self.ensureAvailable(1);
        const val = self.page.data[self.offset];
        self.offset += 1;
        return val;
    }

    pub fn readU32(self: *PageReader) !u32 {
        try self.ensureAvailable(4);
        const buf: *const [4]u8 = @ptrCast(&self.page.data[self.offset]);
        const val = std.mem.readInt(u32, buf, .little);
        self.offset += 4;
        return val;
    }

    pub fn readBytes(self: *PageReader, len: usize) ![]const u8 {
        try self.ensureAvailable(len);
        const bytes = self.page.data[self.offset .. self.offset + len];
        self.offset += len;
        return bytes;
    }

    pub fn readString(self: *PageReader) ![]const u8 {
        const len = try self.readU32();
        return self.readBytes(len);
    }

    pub fn position(self: *PageReader) usize {
        return self.offset;
    }
};
