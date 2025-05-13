const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const File = std.fs.File;
const Page = @import("page.zig").Page;
const PAGE_SIZE = @import("page.zig").PAGE_SIZE;
const DB_FS_DIR = @import("manager.zig").DB_FS_DIR;

pub const FileHandle = struct {
    page_number: usize,
    file: File,
    gpa: Allocator,

    pub fn init(gpa: Allocator, file: File) FileHandle {
        return FileHandle{
            .page_number = 0,
            .file = file,
            .gpa = gpa,
        };
    }

    pub fn close(self: FileHandle) void {
        self.file.close();
    }

    pub fn getFirstPage(self: FileHandle, page: *Page) !void {
        _ = try self.file.pread(&page.data, 0);
        page.number = 0;
    }

    pub fn getLastPage(self: FileHandle, page: *Page) !void {
        const end: usize = @intCast(try self.file.getEndPos());
        page.number = end / PAGE_SIZE;
        _ = try self.file.pread(&page.data, end - PAGE_SIZE);
    }

    pub fn getCurrentPage(self: FileHandle, page: *Page) !void {
        const offset = page.number * PAGE_SIZE;
        _ = try self.file.pread(&page.data, offset);
    }

    pub fn getNextPage(self: FileHandle, page: *Page) !usize {
        page.number += 1;
        const size = try self.file.pread(&page.data, page.number * PAGE_SIZE);
        return size;
    }

    pub fn getPrevPage(self: FileHandle, page: *Page) !void {
        const cur_page = page.number;
        if (page.number > 0) {
            page.number -= 1;
            self.file.pread(page.data, page.number * PAGE_SIZE) catch {
                page.number = cur_page;
                return;
            };
        }
    }

    pub fn allocatePage(self: FileHandle, page: *Page) !void {
        const end = try self.file.getEndPos();
        const new_page_num = end / PAGE_SIZE;

        page.number = new_page_num;
        var zero_buf = [_]u8{0} ** PAGE_SIZE;

        try self.file.seekTo(page.number * PAGE_SIZE);
        try self.file.writeAll(&zero_buf);
    }

    pub fn writePage(self: FileHandle, page: *Page) !void {
        try self.file.seekTo(page.number * PAGE_SIZE);
        try self.file.writeAll(&page.data);
    }

    pub fn advanceAndWritePage(self: FileHandle, page: *Page, pdata: *usize) !void {
        try self.writePage(page);
        page.advancePage();
        pdata.* = 0;
    }
};
