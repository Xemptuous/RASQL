const std = @import("std");
const fs = std.fs;
const ArrayList = std.ArrayList;
const FileHandle = @import("file.zig").FileHandle;
const PAGE_SIZE = @import("page.zig").PAGE_SIZE;

const DB_FS_DIR = "/home/xempt/Git/Personal/rasql/src/dbs/";

const FileOpenFlags = fs.File.OpenFlags{ .mode = fs.File.OpenMode.read_write };

pub const FileManager = struct {
    pub fn createFile(filename: []const u8) !void {
        fs.makeDirAbsolute(DB_FS_DIR) catch {};
        const dir = try fs.openDirAbsolute(DB_FS_DIR, .{});
        _ = try dir.createFile(filename, .{});
    }

    pub fn deleteFile(filename: []const u8) !void {
        const dir = try fs.openDirAbsolute(DB_FS_DIR, .{});
        _ = try dir.deleteFile(filename);
    }

    pub fn openFile(gpa: std.mem.Allocator, filename: []const u8) !FileHandle {
        const dir = try fs.openDirAbsolute(DB_FS_DIR, .{});

        const file = dir.openFile(filename, FileOpenFlags) catch {
            try FileManager.createFile(filename);
            const file = try dir.openFile(filename, FileOpenFlags);
            return FileHandle.init(gpa, file);
        };
        std.debug.print("File: {any}\n", .{file});
        return FileHandle.init(gpa, file);
    }

    pub fn closeFile(filehandle: *FileHandle) void {
        filehandle.file.close();
    }
};
