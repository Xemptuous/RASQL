const std = @import("std");
const ArrayList = std.ArrayList;
const row = @import("../table/row.zig");
const RowValue = row.RowValue;
const DataType = row.DataType;

const Expression = @import("expression.zig").Expression;

pub const StatementType = enum {
    Return,
    CreateRelation,
    UnionRelation,
    DefineStatement,
    ExpressionStatement,
};

pub const Statement = union(StatementType) {
    Return: struct {
        from: *Expression, // Identifier
        project: ArrayList(*Expression), // Identifier
        limit: ?*Expression, // Number
        select: ?ArrayList(*Expression),
    },
    CreateRelation: struct {
        name: []const u8,
        ddl: ArrayList(*Expression),
    },
    UnionRelation: struct {
        left: *Expression, // Identifier
        rows: ArrayList(*Expression),
    },
    DefineStatement: struct {
        name: *Expression,
        from: ?*Expression,
        project: ?ArrayList(*Expression),
        renames: ?ArrayList(*Expression),
        select: ?ArrayList(*Expression),
        expression: ?*Statement,
    },
    ExpressionStatement: struct {
        expression: *Expression,
    },

    pub fn print(self: Statement) void {
        switch (self) {
            .Return => |s| {
                std.debug.print("Statement.Return:\n", .{});
                std.debug.print("  From: ", .{});
                s.from.print();
                std.debug.print("\n", .{});
                std.debug.print("  Project:\n", .{});
                for (s.project.items) |i| {
                    std.debug.print("    ", .{});
                    i.print();
                    std.debug.print("\n", .{});
                }
                if (s.limit != null) {
                    std.debug.print("  Limit: ", .{});
                    s.limit.?.print();
                    std.debug.print("\n", .{});
                }
                std.debug.print("  Select:\n", .{});
                if (s.select != null) {
                    for (s.select.?.items) |i| {
                        std.debug.print("    ", .{});
                        i.print();
                        std.debug.print("\n", .{});
                    }
                }
            },
            .CreateRelation => |s| {
                std.debug.print("Statement.CreateRelation:\n", .{});
                std.debug.print("  Name: {s}\n", .{s.name});
                std.debug.print("  DDL:\n", .{});
                for (s.ddl.items) |i| {
                    std.debug.print("    ", .{});
                    i.print();
                    std.debug.print("\n", .{});
                }
            },
            .ExpressionStatement => |s| {
                std.debug.print("Statement.ExpressionStatement: ", .{});
                s.expression.print();
            },
            .UnionRelation => |u| {
                std.debug.print("Statement.UnionRelation:\n", .{});
                std.debug.print("  Left: ", .{});
                u.left.print();
                std.debug.print("\n  Rows:\n", .{});
                for (u.rows.items) |r| {
                    std.debug.print("    ", .{});
                    r.print();
                    std.debug.print("\n", .{});
                }
            },
            .DefineStatement => |d| {
                std.debug.print("Statement.DefineStatement:\n", .{});
                std.debug.print("  Name: ", .{});
                d.name.print();
                if (d.from != null) {
                    std.debug.print("\n  From: ", .{});
                    d.from.?.print();
                }
                if (d.project != null) {
                    std.debug.print("\n  Project: ", .{});
                    for (d.project.?.items) |p| {
                        p.print();
                        std.debug.print(", ", .{});
                    }
                }
                if (d.renames != null) {
                    std.debug.print("\n  Rename:\n", .{});
                    for (d.renames.?.items) |r| {
                        std.debug.print("    ", .{});
                        r.print();
                        std.debug.print(", ", .{});
                    }
                }
                std.debug.print("\n  Select:\n", .{});
                if (d.select != null) {
                    for (d.select.?.items) |i| {
                        std.debug.print("    ", .{});
                        i.print();
                        std.debug.print("\n", .{});
                    }
                }
                if (d.expression != null) {
                    std.debug.print("\n  Expression: ", .{});
                    d.expression.?.print();
                }
                std.debug.print("\n", .{});
            },
        }
    }
};
