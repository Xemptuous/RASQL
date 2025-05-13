const std = @import("std");
const Allocator = std.mem.Allocator;

const PAGE_SIZE = @import("page/page.zig").PAGE_SIZE;
const PF_FileManager = @import("page/manager.zig").FileManager;

const statement = @import("parser/statement.zig");
const Statement = statement.Statement;

const expression = @import("parser/expression.zig");
const Expression = expression.Expression;

const DataType = @import("table/row.zig").DataType;
const RowValue = @import("table/row.zig").RowValue;
const Column = @import("table/column.zig").Column;
const Table = @import("table/table.zig").Table;

const Lexer = @import("parser/lexer.zig").Lexer;

const Parser = @import("parser/parser.zig").Parser;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    defer statement.StatementArena.deinit();
    defer expression.ExpressionArena.deinit();

    const f = try std.fs.cwd().openFile("input.txt", .{});
    const input = try f.readToEndAlloc(allocator, 10000);

    const lexer = try Lexer.init(input, &allocator);
    defer allocator.destroy(lexer);

    const parser = try Parser.init(&allocator, lexer);
    defer allocator.destroy(parser);

    var timer = try std.time.Timer.start();
    const statements = parser.parse() catch |e| {
        std.debug.print("ERR: {any}", .{e});
        return;
    };
    const elapsed: f64 = @floatFromInt(timer.read());

    defer statements.deinit();
    for (statements.items) |s| {
        s.*.print();
        std.debug.print("\n", .{});
    }

    std.debug.print("Time elapsed: {d:.3}ms\n", .{elapsed / std.time.ns_per_ms});
}

fn generateSampleTable(gpa: Allocator) !*Table {
    var columns = try std.ArrayList(Column).initCapacity(gpa, 3);
    try columns.appendSlice(&[3]Column{
        Column{ .name = "id", .type = .Int32, .nullable = false },
        Column{ .name = "fname", .type = .String, .nullable = false },
        Column{ .name = "is_active", .type = .Boolean, .nullable = false },
    });

    const file = try PF_FileManager.openFile(gpa, "sample_names.txt");
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

// fn writeTableToFile(table: *Table, gpa: Allocator) !void {
//     var file = try PF_FileManager.openFile(gpa, "employee");
//     defer PF_FileManager.closeFile(&file);
//
//     var page = PF_Page.init();
//     var pdata: usize = 0;
//     try table.serialize(&file, &page, &pdata);
//     var table_data = try std.ArrayList(u8).initCapacity(gpa, table.columns.items.len * 10 + table.rows.items.len * 8);
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

    var table_data = try std.ArrayList(u8).init(gpa);
    defer table_data.deinit();

    var pdata: usize = 0;
    try Table.deserialize(&table_data, &pdata, gpa);
}
