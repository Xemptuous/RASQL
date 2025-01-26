const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const File = std.fs.File;
const Page = @import("page.zig").Page;
const PAGE_SIZE = @import("page.zig").PAGE_SIZE;
const DB_FS_DIR = @import("manager.zig").DB_FS_DIR;

// pub const FileType = enum {
//     Data,
//     Index,
// };
//
// pub const Header = struct {
//     type: FileType,
//     column_count: usize,
// };

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

    pub fn deinit(self: FileHandle) !void {
        self.file.close();
        // self.dirty_pages.deinit();
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
        }
        _ = try self.file.pread(page.data, page.number * PAGE_SIZE) catch {
            page.number = cur_page;
        };
        page.number = cur_page;
    }

    pub fn allocatePage(self: FileHandle, page: *Page) !void {
        const size = try self.file.getEndPos();
        if (size / PAGE_SIZE <= PAGE_SIZE) return;
        try self.file.seekTo(page.number * PAGE_SIZE);
        var buf: [PAGE_SIZE]u8 = .{0} ** PAGE_SIZE;
        _ = try self.file.write(&buf);
    }

    pub fn writePage(self: FileHandle, page: *Page) !void {
        try self.file.seekTo(page.number * PAGE_SIZE);
        _ = try self.file.write(&page.data);
    }

    pub fn advanceAndWritePage(self: FileHandle, page: *Page, pdata: *usize) !void {
        try self.writePage(page);
        page.advancePage();
        pdata.* = 0;
    }

    // pub fn markDirty(self: FileHandle, page_num: usize) !void {
    //     try self.dirty_pages.append(page_num);
    // }

    // pub fn disposePage(self: FileHandle, page_num: usize) !void {
    //     const cur_page = page.number;
    //     const tmp_file = try std.fs.createFileAbsolute("/tmp/rasql_out.txt", .{});
    //     const tmp_reader = tmp_file.reader();
    // }
};
