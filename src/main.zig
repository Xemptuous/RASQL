const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const PAGE_SIZE = @import("page/page.zig").PAGE_SIZE;
const PF_FileManager = @import("page/manager.zig").FileManager;
const PF_FileHandle = @import("page/file.zig").FileHandle;
const PF_Page = @import("page/page.zig").Page;

const Statement = @import("parser/statement.zig").Statement;
const Expression = @import("parser/expression.zig").Expression;
const Header = @import("page/header.zig").Header;
const HeaderFileType = @import("page/header.zig").FileType;

const DataType = @import("table/row.zig").DataType;
const Row = @import("table/row.zig").Row;
const RowValue = @import("table/row.zig").RowValue;
const Column = @import("table/column.zig").Column;
const Table = @import("table/table.zig").Table;

const token = @import("parser/token.zig");
const Lexer = @import("parser/lexer.zig").Lexer;

const Parser = @import("parser/parser.zig").Parser;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const f = try std.fs.cwd().openFile("input.txt", .{});
    const input = try f.readToEndAlloc(allocator, 10000);

    const lexer = try Lexer.init(input, allocator);
    defer allocator.destroy(lexer);

    // var tok: token.Token = undefined;
    // while (true) {
    //     tok = try lexer.nextToken();
    //     if (tok.type == token.TokenType.EOF) break;
    //     tok.print();
    // }

    const parser = try Parser.init(allocator, lexer);
    defer allocator.destroy(parser);

    const statements = parser.parse() catch |e| {
        std.debug.print("ERR: {any}", .{e});
        return;
    };
    defer statements.deinit();
    for (statements.items) |s| {
        s.*.print();
        std.debug.print("\n", .{});
    }
}

fn generateSampleTable(gpa: Allocator) !*Table {
    var columns = try ArrayList(Column).initCapacity(gpa, 3);
    try columns.appendSlice(&[3]Column{
        Column{ .name = "id", .type = DataType.Int32, .nullable = false },
        Column{ .name = "fname", .type = DataType.String, .nullable = false },
        Column{ .name = "is_active", .type = DataType.Boolean, .nullable = false },
    });

    const file = try PF_FileManager.openFile(gpa, "sample_names.txt");
    defer file.file.close();

    var rows = ArrayList(RowValue).init(gpa);

    var buf_reader = std.io.bufferedReader(file.file.reader());
    var in_stream = buf_reader.reader();
    const rand = std.crypto.random;
    var id: u32 = 0;
    while (try in_stream.readUntilDelimiterOrEofAlloc(gpa, '\n', 64)) |line| {
        try rows.appendSlice(&[_]RowValue{
            RowValue{ .Uint32 = id },
            RowValue{ .String = line },
            RowValue{ .Boolean = rand.boolean() },
        });
        id += 1;
    }

    var table = try Table.init(gpa);
    table.columns = columns;
    table.rows = rows;

    return table;
}

// fn writeTableToFile(table: *Table, gpa: Allocator) !void {
//     var file = try PF_FileManager.openFile(gpa, "employee");
//     defer PF_FileManager.closeFile(&file);
//
//     var page = PF_Page.init();
//     var pdata: usize = 0;
//     try table.serialize(&file, &page, &pdata);
//     var table_data = try ArrayList(u8).initCapacity(gpa, table.columns.items.len * 10 + table.rows.items.len * 8);
//     defer table_data.deinit();
//
//     {
//         var pdata: usize = 0;
//         try table.serialize(&table_data, &pdata, gpa);
//
//         const n = table_data.items.len;
//         const div = n % PAGE_SIZE;
//         if (div != 0) {
//             const new_size = n + (PAGE_SIZE - div);
//             try table_data.resize(new_size);
//             for (n..new_size) |i|
//                 table_data.items[i] = 0;
//         }
//     }
//
//     const n = table_data.items.len;
//     var page = PF_Page.init();
//
//     var data: [PAGE_SIZE]u8 = .{0} ** PAGE_SIZE;
//     while (page.number * PAGE_SIZE < n) {
//         {
//             const start = page.number * PAGE_SIZE;
//             const end = start + PAGE_SIZE;
//             @memcpy(&data, table_data.items[start..end]);
//
//             // early return if page unmodified
//             if (std.mem.eql(u8, &page.data, &data)) {
//                 _ = try file.getNextPage(&page);
//                 continue;
//             }
//         }
//
//         @memcpy(&page.data, &data);
//
//         try file.writePage(&page);
//         _ = try file.getNextPage(&page);
//     }
// }

fn readTableFromFile(gpa: Allocator) !void {
    var file = try PF_FileManager.openFile(gpa, "employee");
    defer PF_FileManager.closeFile(&file);

    var table_data = try ArrayList(u8).init(gpa);
    defer table_data.deinit();

    var pdata: usize = 0;
    try Table.deserialize(&table_data, &pdata, gpa);
}
