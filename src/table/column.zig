const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const DataType = @import("row.zig").DataType;
const PAGE_SIZE = @import("../page/page.zig").PAGE_SIZE;
const Page = @import("../page/page.zig").Page;
const FileHandle = @import("../page/file.zig").FileHandle;
const PageWriter = @import("../page/writer.zig").PageWriter;
const PageReader = @import("../page/reader.zig").PageReader;

pub const Column = struct {
    name: []const u8,
    type: DataType,
    nullable: bool,

    pub fn serialize(self: Column, writer: *PageWriter) !void {
        const strlen: u32 = @intCast(self.name.len);
        try writer.writeU32(strlen);
        try writer.writeBytes(self.name);
        try writer.writeU8(@intFromEnum(self.type));
        try writer.writeU8(@intFromBool(self.nullable));
    }

    pub fn deserialize(reader: *PageReader, allocator: Allocator) !Column {
        const name_len = try reader.readU32();
        const name_bytes = try reader.readBytes(name_len);
        const name = try allocator.dupe(u8, name_bytes); // clone if needed

        const type_raw = try reader.readU8();
        const nullable = try reader.readU8();

        return Column{
            .name = name,
            .type = @enumFromInt(type_raw),
            .nullable = nullable != 0,
        };
    }
};
