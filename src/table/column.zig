const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const DataType = @import("row.zig").DataType;
const PAGE_SIZE = @import("../page/page.zig").PAGE_SIZE;
const Page = @import("../page/page.zig").Page;
const FileHandle = @import("../page/file.zig").FileHandle;

pub const Column = struct {
    name: []const u8,
    type: DataType,
    nullable: bool,

    pub fn serialize(self: Column, file: *FileHandle, page: *Page, pdata: *usize) !void {
        // column length
        const strlen: u32 = @intCast(self.name.len);
        if (pdata.* + 6 + strlen > PAGE_SIZE) try file.advanceAndWritePage(page, pdata);
        var lenbuf: [4]u8 = .{0} ** 4;
        lenbuf = @bitCast(strlen);
        @memcpy(page.data[pdata.* .. pdata.* + 4], &lenbuf);
        pdata.* += 4;

        // column string
        for (0..strlen, pdata.*..strlen + pdata.*) |i, j|
            page.data[j] = self.name[i];
        pdata.* += strlen;

        // DataType
        const dtype: u8 = @intFromEnum(self.type);
        // @memset(page.data[pdata.*..pdata.*], dtype);
        page.data[pdata.*] = dtype;
        pdata.* += 1;

        // nullable
        @memset(page.data[pdata.*..pdata.*], if (self.nullable) 1 else 0);
        pdata.* += 1;
    }

    // pub fn serialize(self: Column, buffer: *ArrayList(u8), pdata: *usize, gpa: Allocator) !void {
    //     // column length
    //     const strlen: u32 = @intCast(self.name.len);
    //     var lenbuf: [4]u8 = .{0} ** 4;
    //     lenbuf = @bitCast(strlen);
    //     try buffer.appendSlice(&lenbuf);
    //     pdata.* += 4;
    //
    //     // column string
    //     var strbuf = try ArrayList(u8).initCapacity(gpa, strlen);
    //     defer strbuf.deinit();
    //     for (self.name) |c|
    //         try strbuf.append(c);
    //     try buffer.appendSlice(strbuf.items);
    //     pdata.* += strlen;
    //
    //     // DataType
    //     try buffer.append(@intFromEnum(self.type));
    //     pdata.* += 1;
    //
    //     // nullable
    //     var buf: [1]u8 = .{if (self.nullable) 1 else 0};
    //     try buffer.appendSlice(&buf);
    //     pdata.* += 1;
    // }

    pub fn deserialize(buffer: []u8, pdata: *usize) !Column {
        // column length
        const ulen: u32 = std.mem.bytesToValue(u32, buffer[pdata.* .. pdata.* + 4]);
        const col_len: usize = @as(usize, ulen);
        pdata.* += 4;

        // column string
        const name: []u8 = buffer[pdata.* .. pdata.* + col_len];
        pdata.* += col_len;

        // DataType
        const dtype: DataType = @enumFromInt(buffer[pdata.*]);
        pdata.* += 1;

        // nullable
        const nullable: u8 = buffer[pdata.*];
        pdata.* += 1;

        return Column{ .name = name, .type = dtype, .nullable = nullable == 1 };
    }
};
