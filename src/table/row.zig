const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const PAGE_SIZE = @import("../page/page.zig").PAGE_SIZE;
const Page = @import("../page/page.zig").Page;
const FileHandle = @import("../page/file.zig").FileHandle;

const DataType = @import("../parser/expression.zig").DataType;

pub const Row = ArrayList(RowValue);

pub const RowValue = union(DataType) {
    Int8: i8,
    Int16: i16,
    Int32: i32,
    Int64: i64,
    Uint8: i8,
    Uint16: i16,
    Uint32: i32,
    Uint64: i64,
    Float32: f32,
    Float64: f64,
    Boolean: bool,
    String: []const u8,
    Date: []const u8,
    Timestamp: []const u8,

    // pub fn serialize(self: RowValue, buffer: *ArrayList(u8), pdata: *usize, gpa: Allocator) !void {
    //     switch (self) {
    //         .String => |s| {
    //             try buffer.append(@intFromEnum(DataType.String));
    //             const len: u32 = @intCast(s.len);
    //
    //             var lenbuf: [4]u8 = .{0} ** 4;
    //             lenbuf = @bitCast(len);
    //             try buffer.appendSlice(&lenbuf);
    //             pdata.* += 4;
    //
    //             var strbuf = try ArrayList(u8).initCapacity(gpa, len);
    //             defer strbuf.deinit();
    //             for (s) |c|
    //                 try strbuf.append(c);
    //             pdata.* += len;
    //
    //             try buffer.appendSlice(strbuf.items);
    //         },
    //         .Uint32 => |u| {
    //             try buffer.append(@intFromEnum(DataType.Uint32));
    //             var buf: [4]u8 = .{0} ** 4;
    //             buf = @bitCast(u);
    //             try buffer.appendSlice(&buf);
    //             pdata.* += 4;
    //         },
    //         .Int32 => |i| {
    //             try buffer.append(@intFromEnum(DataType.Int32));
    //             var buf: [4]u8 = .{0} ** 4;
    //             buf = @bitCast(i);
    //             try buffer.appendSlice(&buf);
    //             pdata.* += 4;
    //         },
    //         .Float32 => |f| {
    //             try buffer.append(@intFromEnum(DataType.Float32));
    //             var buf: [4]u8 = .{0} ** 4;
    //             buf = @bitCast(f);
    //             try buffer.appendSlice(&buf);
    //             pdata.* += 4;
    //         },
    //         .Boolean => |b| {
    //             try buffer.append(@intFromEnum(DataType.Boolean));
    //             var buf: [1]u8 = .{if (b) 1 else 0};
    //             try buffer.appendSlice(&buf);
    //             pdata.* += 1;
    //         },
    //     }
    // }

    pub fn serialize(self: RowValue, file: *FileHandle, page: *Page, pdata: *usize) !void {
        switch (self) {
            .String => |s| {
                const len: u32 = @intCast(s.len);
                if (pdata.* + 5 + len > PAGE_SIZE) try file.advanceAndWritePage(page, pdata);
                const dtype: u8 = @intFromEnum(DataType.String);
                // @memset(page.data[pdata.*..pdata.*], dtype);
                page.data[pdata.*] = dtype;
                pdata.* += 1;

                var lenbuf: [4]u8 = .{0} ** 4;
                lenbuf = @bitCast(len);
                @memcpy(page.data[pdata.* .. pdata.* + 4], &lenbuf);
                pdata.* += 4;

                for (0.., pdata.*..s.len + pdata.*) |i, j|
                    page.data[j] = s[i];
                pdata.* += len;
            },
            .Int32 => |i| {
                if (pdata.* + 5 > PAGE_SIZE) try file.advanceAndWritePage(page, pdata);
                const dtype: u8 = @intFromEnum(DataType.Int32);
                // @memset(page.data[pdata.*..pdata.*], dtype);
                page.data[pdata.*] = dtype;
                pdata.* += 1;

                var buf: [4]u8 = .{0} ** 4;
                buf = @bitCast(i);
                @memcpy(page.data[pdata.* .. pdata.* + 4], &buf);
                pdata.* += 4;
            },
            .Uint32 => |u| {
                if (pdata.* + 5 > PAGE_SIZE) try file.advanceAndWritePage(page, pdata);
                const dtype: u8 = @intFromEnum(DataType.Uint32);
                // @memset(page.data[pdata.*..pdata.*], dtype);
                page.data[pdata.*] = dtype;
                pdata.* += 1;

                var buf: [4]u8 = .{0} ** 4;
                buf = @bitCast(u);
                @memcpy(page.data[pdata.* .. pdata.* + 4], &buf);
                pdata.* += 4;
            },
            .Float32 => |f| {
                if (pdata.* + 5 > PAGE_SIZE) try file.advanceAndWritePage(page, pdata);
                const dtype: u8 = @intFromEnum(DataType.Float32);
                @memset(page.data[pdata.*..pdata.*], dtype);
                pdata.* += 1;

                var buf: [4]u8 = .{0} ** 4;
                buf = @bitCast(f);
                @memcpy(page.data[pdata.* .. pdata.* + 4], &buf);
                pdata.* += 4;
            },
            .Boolean => |b| {
                if (pdata.* + 2 > PAGE_SIZE) try file.advanceAndWritePage(page, pdata);
                const dtype: u8 = @intFromEnum(DataType.Boolean);
                // @memset(page.data[pdata.*..pdata.*], dtype);
                page.data[pdata.*] = dtype;
                pdata.* += 1;

                // @memset(page.data[pdata.*..pdata.*], if (b) 1 else 0);
                page.data[pdata.*] = if (b) 1 else 0;
                pdata.* += 1;
            },
        }
    }

    pub fn deserialize(buffer: []u8, pdata: *usize) ?RowValue {
        if (buffer.len == 0) {
            return null;
        }
        const dtype: DataType = @enumFromInt(buffer[pdata.*]);
        pdata.* += 1;

        switch (dtype) {
            DataType.String => {
                const ulen: u32 = std.mem.bytesToValue(u32, buffer[pdata.* .. pdata.* + 4]);
                const str_len: usize = @as(usize, ulen);
                pdata.* += 4;

                const data = buffer[pdata.* .. pdata.* + str_len];
                pdata.* += str_len;
                return RowValue{ .String = data };
            },
            DataType.Uint32 => {
                const res: u32 = std.mem.bytesToValue(u32, buffer[pdata.* .. pdata.* + 4]);
                pdata.* += 4;
                return RowValue{ .Uint32 = res };
            },
            DataType.Int32 => {
                const res: i32 = std.mem.bytesToValue(i32, buffer[pdata.* .. pdata.* + 4]);
                pdata.* += 4;
                return RowValue{ .Int32 = res };
            },
            DataType.Float32 => {
                const res: f32 = std.mem.bytesToValue(f32, buffer[pdata.* .. pdata.* + 4]);
                pdata.* += 4;
                return RowValue{ .Float32 = res };
            },
            DataType.Boolean => {
                const res: u8 = buffer[pdata.*];
                pdata.* += 1;
                return RowValue{ .Boolean = res == 1 };
            },
            else => {},
        }
        return null;
    }
};
