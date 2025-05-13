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
const FileManager = @import("../page/manager.zig").FileManager;
const PageWriter = @import("../page/writer.zig").PageWriter;
const PageReader = @import("../page/reader.zig").PageReader;

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
        self.rows.deinit();
        self.gpa.destroy(self);
    }

    pub fn serialize(self: *Table, writer: *PageWriter) !void {
        try writer.writeU32(@intCast(self.columns.items.len));

        for (self.columns.items) |column|
            try column.serialize(writer);

        for (self.rows.items) |row|
            try row.serialize(writer);
    }

    pub fn deserialize(reader: *PageReader, allocator: Allocator) !Table {
        var table = Table{
            .gpa = allocator,
            .columns = ArrayList(Column).init(allocator),
            .rows = ArrayList(RowValue).init(allocator),
        };

        const column_count = try reader.readU32();
        std.debug.print("Col Count: {d}\n", .{column_count});
        try table.columns.ensureTotalCapacity(column_count);
        for (0..column_count) |_| {
            const column = try Column.deserialize(reader, allocator);
            try table.columns.append(column);
        }
        for (table.columns.items) |col| {
            std.debug.print("Column: {any}\n", .{col});
        }

        while (reader.position() < PAGE_SIZE) {
            const row = try RowValue.deserialize(reader, allocator);
            try table.rows.append(row);
        }

        return table;
    }

    pub fn writeToFile(table: *Table, gpa: Allocator) !void {
        var file = try FileManager.openFile(gpa, "people");
        defer file.close();
        std.debug.print("file: {any}\n", .{file});
        // defer PF_FileManager.closeFile(&file);

        var page = Page.init();
        var writer = PageWriter.init(&file, &page);
        try table.serialize(&writer);
    }

    pub fn readFromFile(gpa: Allocator) !Table {
        var file = try FileManager.openFile(gpa, "people");
        defer file.close();
        // defer PF_FileManager.closeFile(&file);
        var page = Page.init();
        try file.getFirstPage(&page);
        var reader = PageReader.init(&file, &page);
        const table = try Table.deserialize(&reader, gpa);
        std.debug.print("Table: {any}", .{table});
        return table;
    }
};

pub fn generateSampleTable(gpa: Allocator) !*Table {
    var columns = try std.ArrayList(Column).initCapacity(gpa, 3);
    try columns.appendSlice(&[3]Column{
        Column{ .name = "id", .type = .Int32, .nullable = false },
        Column{ .name = "fname", .type = .String, .nullable = false },
        Column{ .name = "is_active", .type = .Boolean, .nullable = false },
    });

    const file = try FileManager.openFile(gpa, "sample_names.txt");
    defer file.file.close();

    var rows = std.ArrayList(RowValue).init(gpa);

    var buf_reader = std.io.bufferedReader(file.file.reader());
    var in_stream = buf_reader.reader();
    const rand = std.crypto.random;
    var id: u32 = 0;
    while (try in_stream.readUntilDelimiterOrEofAlloc(gpa, '\n', 64)) |line| {
        try rows.appendSlice(&[_]RowValue{
            .{ .Uint32 = id },
            .{ .String = line },
            .{ .Boolean = rand.boolean() },
        });
        id += 1;
    }

    var table = try Table.init(gpa);
    table.columns = columns;
    table.rows = rows;

    return table;
}
