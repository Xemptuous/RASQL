const std = @import("std");
const ArrayList = std.ArrayList;
const row = @import("../table/row.zig");
const RowValue = row.RowValue;
const DataType = row.DataType;

const Expression = @import("expression.zig").Expression;

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

pub const Return = struct {
    from: *Expression, // Identifier
    project: ArrayList(*Expression), // Identifier
    limit: ?*Expression, // Number
    select: ?ArrayList(*Expression),
};

pub const CreateRelation = struct {
    name: FullyQualifiedName,
    primary_keys: ArrayList(*Expression),
    foreign_keys: ArrayList(*Expression),
    columns: ArrayList(*Expression),
};

pub const DeleteRelation = []const u8;

pub const UnionRelation = struct {
    left: FullyQualifiedName,
    rows: ArrayList(*Expression),
};

pub const ExpressionStatement = struct {
    expression: *Expression,
};

pub const DefineStatement = struct {
    name: *Expression, // Identifier
    from: ?*Expression, // Identifier
    project: ?ArrayList(*Expression),
    renames: ?ArrayList(*Expression),
    select: ?ArrayList(*Expression),
    expression: ?*Statement,
};
pub const CreateSchema = struct {
    name: *Expression, // Identifier
    relations: ?ArrayList(*Statement), // CreateRelation statements
};

pub const DeleteSchema = []const u8;

pub const CreateDatabase = *Expression; // Identifier
pub const DeleteDatabase = *Expression; // Identifier
pub const DefineDatabase = struct {
    name: *Expression, // Identifier
    schema: ArrayList(*Statement),
};

pub const Statement = union(StatementType) {
    Return: *const Return,

    // Schema
    CreateSchema: *const CreateSchema,
    DeleteSchema: *const DeleteSchema,

    // Database
    CreateDatabase: *const CreateDatabase,
    DeleteDatabase: *const DeleteDatabase,
    DefineDatabase: *const DefineDatabase,

    // Relation
    CreateRelation: *const CreateRelation,
    DeleteRelation: *const DeleteRelation,
    UnionRelation: *const UnionRelation,

    DefineStatement: *const DefineStatement,
    ExpressionStatement: *const ExpressionStatement,

    pub fn print(self: Statement) void {
        switch (self) {
            .Return => |s| {
                std.debug.print("Statement.Return:\n", .{});
                std.debug.print("  From: ", .{});
                s.*.from.print();
                std.debug.print("\n", .{});
                std.debug.print("  Project:\n", .{});
                for (s.*.project.items) |i| {
                    std.debug.print("    ", .{});
                    i.print();
                    std.debug.print("\n", .{});
                }
                if (s.*.limit != null) {
                    std.debug.print("  Limit: ", .{});
                    s.*.limit.?.print();
                    std.debug.print("\n", .{});
                }
                std.debug.print("  Select:\n", .{});
                if (s.*.select != null) {
                    for (s.*.select.?.items) |i| {
                        std.debug.print("    ", .{});
                        i.print();
                        std.debug.print("\n", .{});
                    }
                }
            },
            .CreateRelation => |s| {
                std.debug.print("Statement.CreateRelation:\n", .{});
                std.debug.print("  Name: ", .{});
                s.*.name.print();
                std.debug.print("\n  Columns:\n", .{});
                for (s.*.columns.items) |i| {
                    std.debug.print("    ", .{});
                    i.print();
                    std.debug.print("\n", .{});
                }
                if (s.*.primary_keys.items.len != 0) {
                    std.debug.print("  Primary Key: ( ", .{});
                    for (s.*.primary_keys.items) |i| {
                        i.print();
                        std.debug.print(", ", .{});
                    }
                    std.debug.print(" )\n", .{});
                }
                if (s.*.foreign_keys.items.len != 0) {
                    std.debug.print("  Foreign Keys:\n", .{});
                    for (s.*.foreign_keys.items) |i| {
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
                if (d.select != null) {
                    std.debug.print("\n  Select:\n", .{});
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
            else => {},
        }
    }
};
