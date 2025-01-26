const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Row = @import("row.zig").Row;
const RowValue = @import("row.zig").RowValue;
const Column = @import("column.zig").Column;
const DataType = @import("row.zig").DataType;
const PAGE_SIZE = @import("../page/page.zig").PAGE_SIZE;
const Page = @import("../page/page.zig").Page;
const FileHandle = @import("../page/file.zig").FileHandle;

pub const Table = struct {
    columns: ArrayList(Column),
    rows: ArrayList(RowValue),
    gpa: Allocator,

    pub fn init(gpa: Allocator) !*Table {
        const t = try gpa.create(Table);
        t.* = .{
            .columns = ArrayList(Column).init(gpa),
            .rows = ArrayList(RowValue).init(gpa),
            .gpa = gpa,
        };
        return t;
    }

    pub fn deinit(self: *Table) void {
        self.columns.deinit();
        // for (self.rows.items) |row| {
        //     switch (row) {
        //         DataType.String => |s| self.gpa.free(s),
        //         else => {},
        //     }
        // }
        self.rows.deinit();
        self.gpa.destroy(self);
    }

    pub fn serialize(self: *Table, file: *FileHandle, page: *Page, pdata: *usize) !void {
        // number of columns
        _ = try self.serializeNumberOfColumns(file, page, pdata);

        for (self.columns.items) |column| {
            try column.serialize(file, page, pdata);
        }

        for (self.rows.items) |row| {
            try row.serialize(file, page, pdata);
        }
    }

    // pub fn serialize(self: *Table, buffer: *ArrayList(u8), pdata: *usize, gpa: Allocator) !void {
    //     // number of columns
    //     _ = try self.serializeNumberOfColumns(buffer, pdata);
    //
    //     for (self.columns.items) |column| {
    //         try column.serialize(buffer, pdata, gpa);
    //     }
    //
    //     for (self.rows.items) |row| {
    //         try row.serialize(buffer, pdata, gpa);
    //     }
    // }

    pub fn serializeNumberOfColumns(self: *Table, file: *FileHandle, page: *Page, pdata: *usize) !u32 {
        const len: u32 = @intCast(self.columns.items.len);
        var lenbuf: [4]u8 = .{0} ** 4;
        lenbuf = @bitCast(len);
        if (pdata.* + 4 > PAGE_SIZE) try file.advanceAndWritePage(page, pdata);
        @memcpy(page.data[pdata.* .. pdata.* + 4], &lenbuf);
        // try buffer.appendSlice(&lenbuf);
        pdata.* += 4;
        return len;
    }

    // pub fn serializeNumberOfColumns(self: *Table, buffer: *ArrayList(u8), pdata: *usize) !u32 {
    //     const len: u32 = @intCast(self.columns.items.len);
    //     var lenbuf: [4]u8 = .{0} ** 4;
    //     lenbuf = @bitCast(len);
    //     try buffer.appendSlice(&lenbuf);
    //     pdata.* += 4;
    //     return len;
    // }

    pub fn deserializeNumberOfColumns(buffer: []u8, pdata: *usize) !usize {
        const ulen: u32 = std.mem.bytesToValue(u32, buffer[pdata.* .. pdata.* + 4]);
        const col_len: usize = @as(usize, ulen);
        pdata.* += 4;
        return col_len;
    }

    pub fn deserializeColumns(self: *Table, buffer: []u8, pdata: *usize) !void {
        const ulen: u32 = std.mem.bytesToValue(u32, buffer[pdata.* .. pdata.* + 4]);
        const col_len: usize = @as(usize, ulen);
        pdata.* += 4;

        for (0..col_len) |_| {
            const col = try Column.deserialize(buffer, pdata);
            try self.columns.append(col);
        }
    }

    // pub fn deserializeRows(self: Table, buffer: *ArrayList(u8)) !void {
    //     for (self.rows.items) |row| {
    //         try row.deserialize(buffer, pdata);
    //     }
    // }

    // pub fn deserialize(self: Table, buffer: *ArrayList(u8), pdata: *usize, gpa: Allocator) !void {
    //     // number of columns
    //     const ulen: u32 = std.mem.bytesToValue(u32, buffer[pdata.* .. pdata.* + 4]);
    //     const len: usize = @as(usize, ulen);
    //     pdata.* += 4;
    // }
};
