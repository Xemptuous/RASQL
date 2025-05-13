const std = @import("std");
const row = @import("../table/row.zig");
const RowValue = row.RowValue;
const DataType = row.DataType;

const Expression = @import("expression.zig").Expression;

pub var StatementArena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
pub const StatementArenaAllocator = StatementArena.allocator();

pub const StatementType = enum {
    Return,
    CreateSchema,
    DeleteSchema,
    CreateDatabase,
    DeleteDatabase,
    DefineDatabase,
    CreateRelation,
    DeleteRelation,
    UnionRelation,
    DefineStatement,
    ExpressionStatement,
};

pub const FullyQualifiedName = struct {
    db: ?*Expression,
    group: ?*Expression,
    relation: ?*Expression,

    pub fn print(self: FullyQualifiedName) void {
        if (self.db != null) {
            self.db.?.print();
            std.debug.print(".", .{});
        }
        if (self.group != null) {
            self.group.?.print();
            std.debug.print(".", .{});
        }
        if (self.relation != null)
            self.relation.?.print();
    }
};

pub const Statement = union(StatementType) {
    Return: struct {
        from: *Expression, // Identifier
        project: []Expression, // Identifier
        limit: ?*Expression, // Number
        select: ?[]Expression,
    },

    // Schema
    CreateSchema: struct {
        name: []const u8,
        relations: ?[]Statement, // CreateRelation statements
    },
    DeleteSchema: []const u8,

    // Database
    CreateDatabase: *Expression, // Identifier
    DeleteDatabase: *Expression, // Identifier
    DefineDatabase: struct {
        name: *Expression, // Identifier
        schema: []Statement,
    },

    // Relation
    CreateRelation: struct {
        name: FullyQualifiedName,
        primary_keys: []Expression,
        foreign_keys: []Expression,
        columns: []Expression,
    },
    DeleteRelation: []const u8,
    UnionRelation: struct {
        left: FullyQualifiedName,
        rows: []Expression,
    },

    DefineStatement: struct {
        name: *Expression,
        from: ?*Expression,
        project: ?[]Expression,
        renames: ?[]Expression,
        select: ?[]Expression,
        expression: ?*Statement,
    },
    ExpressionStatement: struct {
        expression: *Expression,
    },

    pub fn new(comptime t: StatementType, data: anytype) !*Statement {
        const s = try StatementArenaAllocator.create(Statement);
        s.* = switch (t) {
            .Return => .{ .Return = data },
            .CreateSchema => .{ .CreateSchema = data },
            .DeleteSchema => .{ .DeleteSchema = data },
            .CreateDatabase => .{ .CreateDatabase = data },
            .DeleteDatabase => .{ .DeleteDatabase = data },
            .DefineDatabase => .{ .DefineDatabase = data },
            .CreateRelation => .{ .CreateRelation = data },
            .DeleteRelation => .{ .DeleteRelation = data },
            .UnionRelation => .{ .UnionRelation = data },
            .DefineStatement => .{ .DefineStatement = data },
            .ExpressionStatement => .{ .ExpressionStatement = data },
        };
        return s;
    }

    pub fn print(self: Statement) void {
        switch (self) {
            .Return => |s| {
                std.debug.print("Statement.Return:\n", .{});
                std.debug.print("  From: ", .{});
                s.from.print();
                std.debug.print("\n", .{});
                std.debug.print("  Project:\n", .{});
                for (s.project) |i| {
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
                    for (s.select.?) |i| {
                        std.debug.print("    ", .{});
                        i.print();
                        std.debug.print("\n", .{});
                    }
                }
            },
            .CreateRelation => |s| {
                std.debug.print("Statement.CreateRelation:\n", .{});
                std.debug.print("  Name: ", .{});
                s.name.print();
                std.debug.print("\n  Columns:\n", .{});
                for (s.columns) |i| {
                    std.debug.print("    ", .{});
                    i.print();
                    std.debug.print("\n", .{});
                }
                if (s.primary_keys.len != 0) {
                    std.debug.print("  Primary Key: ( ", .{});
                    for (s.primary_keys) |i| {
                        i.print();
                        std.debug.print(", ", .{});
                    }
                    std.debug.print(" )\n", .{});
                }
                if (s.foreign_keys.len != 0) {
                    std.debug.print("  Foreign Keys:\n", .{});
                    for (s.foreign_keys) |i| {
                        std.debug.print("    ", .{});
                        i.print();
                        std.debug.print(",\n", .{});
                    }
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
                for (u.rows) |r| {
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
                    for (d.project.?) |p| {
                        p.print();
                        std.debug.print(", ", .{});
                    }
                }
                if (d.renames != null) {
                    std.debug.print("\n  Rename:\n", .{});
                    for (d.renames.?) |r| {
                        std.debug.print("    ", .{});
                        r.print();
                        std.debug.print(", ", .{});
                    }
                }
                if (d.select != null) {
                    std.debug.print("\n  Select:\n", .{});
                    for (d.select.?) |i| {
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
            else => {},
        }
    }
};
