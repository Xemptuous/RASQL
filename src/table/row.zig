const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const PAGE_SIZE = @import("../page/page.zig").PAGE_SIZE;
const Page = @import("../page/page.zig").Page;
const PageWriter = @import("../page/writer.zig").PageWriter;
const PageReader = @import("../page/reader.zig").PageReader;
const FileHandle = @import("../page/file.zig").FileHandle;

pub const DataType = @import("../parser/expression.zig").DataType;

pub const Row = ArrayList(RowValue);

pub const RowValue = union(DataType) {
    Int8: i8,
    Int16: i16,
    Int32: i32,
    Int64: i64,
    Uint8: u8,
    Uint16: u16,
    Uint32: u32,
    Uint64: u64,
    Float32: f32,
    Float64: f64,
    Boolean: bool,
    String: []const u8,
    Date: []const u8,
    Timestamp: []const u8,

    pub fn serialize(self: RowValue, writer: *PageWriter) !void {
        switch (self) {
            .Int32 => |i| {
                try writer.writeU8(@intFromEnum(DataType.Int32));
                try writer.writeU32(@intCast(i));
            },
            .Uint32 => |u| {
                try writer.writeU8(@intFromEnum(DataType.Uint32));
                try writer.writeU32(u);
            },
            .Float32 => |f| {
                try writer.writeU8(@intFromEnum(DataType.Float32));
                try writer.writeU32(@intFromFloat(f));
            },
            .Boolean => |b| {
                try writer.writeU8(@intFromEnum(DataType.Boolean));
                try writer.writeU8(@intFromBool(b));
            },
            .String => |s| {
                try writer.writeU8(@intFromEnum(DataType.String));
                try writer.writeString(s);
            },
            else => {
                std.debug.print("ELSE\n", .{});
            },
        }
    }

    pub fn deserialize(reader: *PageReader, allocator: Allocator) !RowValue {
        const type_tag = try reader.readU8();
        const dtype: DataType = @enumFromInt(type_tag);
        std.debug.print("tag: {d} dtype: {any}\n", .{ type_tag, dtype });

        return switch (dtype) {
            .Int32 => RowValue{ .Int32 = @intCast(try reader.readU32()) },
            .Uint32 => RowValue{ .Uint32 = try reader.readU32() },
            .Float32 => {
                const f: f32 = @bitCast(try reader.readU32());
                return RowValue{ .Float32 = @floatCast(f) };
            },
            .Boolean => RowValue{ .Boolean = try reader.readU8() != 0 },
            .String => RowValue{ .String = try allocator.dupe(u8, try reader.readString()) },
            else => error.UnknownDataType,
        };
    }
};
