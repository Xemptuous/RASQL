const std = @import("std");
const Allocator = std.mem.Allocator;

const PAGE_SIZE = @import("page/page.zig").PAGE_SIZE;

const statement = @import("parser/statement.zig");
const expression = @import("parser/expression.zig");

const table = @import("table/table.zig");
const Table = table.Table;

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
    // for (statements.items) |s| {
    //     s.*.print();
    //     std.debug.print("\n", .{});
    // }

    std.debug.print("Time elapsed: {d:.3}ms\n", .{elapsed / std.time.ns_per_ms});
    var tbl = try Table.readFromFile(allocator);
    try Table.writeToFile(&tbl, allocator);
}

fn testIO(allocator: Allocator) !void {
    // var tbl = table.generateSampleTable(allocator);
    var tbl = try Table.readFromFile(allocator);
    try Table.writeToFile(&tbl, allocator);
}
