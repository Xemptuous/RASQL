const std = @import("std");
const ArrayList = std.ArrayList;
const TokenType = @import("token.zig").TokenType;
const Decimal = struct { length: u8, precision: u8 };

pub const DataType = enum(u8) {
    Int8,
    Int16,
    Int32,
    Int64,
    Uint8,
    Uint16,
    Uint32,
    Uint64,
    Float32,
    Float64,
    Boolean,
    String,
    Date,
    Timestamp,
    _,

    pub fn print(self: DataType) void {
        switch (self) {
            .Int8 => std.debug.print("Int8", .{}),
            .Int16 => std.debug.print("Int16", .{}),
            .Int32 => std.debug.print("Int32", .{}),
            .Int64 => std.debug.print("Int64", .{}),
            .Uint8 => std.debug.print("Uint8", .{}),
            .Uint16 => std.debug.print("Uint16", .{}),
            .Uint32 => std.debug.print("Uint32", .{}),
            .Uint64 => std.debug.print("Uint64", .{}),
            .Float32 => std.debug.print("Float32", .{}),
            .Float64 => std.debug.print("Float64", .{}),
            .Boolean => std.debug.print("Boolean", .{}),
            .String => std.debug.print("String", .{}),
            .Date => std.debug.print("Date", .{}),
            .Timestamp => std.debug.print("Timestamp", .{}),
            _ => {},
        }
    }
};

pub const NumberDataType = enum {
    Int8,
    Int16,
    Int32,
    Int64,
    Uint8,
    Uint16,
    Uint32,
    Uint64,
    Float32,
    Float64,
};

pub const NumberUnion = union(NumberDataType) {
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

    pub fn print(self: NumberUnion) void {
        switch (self) {
            .Int8 => |n| std.debug.print("{?}", .{n}),
            .Int16 => |n| std.debug.print("{?}", .{n}),
            .Int32 => |n| std.debug.print("{?}", .{n}),
            .Int64 => |n| std.debug.print("{?}", .{n}),
            .Uint8 => |n| std.debug.print("{?}", .{n}),
            .Uint16 => |n| std.debug.print("{?}", .{n}),
            .Uint32 => |n| std.debug.print("{?}", .{n}),
            .Uint64 => |n| std.debug.print("{?}", .{n}),
            .Float32 => |n| std.debug.print("{?}", .{n}),
            .Float64 => |n| std.debug.print("{?}", .{n}),
        }
    }
};

pub const ExpressionType = enum {
    ColumnDDL,
    ForeignKey,
    SelectDML,
    InfixExpression,
    ProjectClause,
    RenameClause,
    Rows,
    Identifier,
    String,
    Number,
    Boolean,
};

pub const Expression = union(ExpressionType) {
    ColumnDDL: struct {
        name: []const u8,
        dtype: DataType,
    },
    ForeignKey: struct {
        column: *Expression, // Identifier
        table: *Expression, // Identifier
    },
    SelectDML: ArrayList(*Expression),
    InfixExpression: struct {
        left: *Expression,
        op: []const u8,
        right: *Expression,
    },
    ProjectClause: ArrayList(*Expression),
    RenameClause: struct {
        from: *Expression, // Identifier
        to: *Expression, // Identifier
    },
    Rows: ArrayList(*Expression),
    Identifier: []const u8,
    String: []const u8,
    Number: NumberUnion,
    Boolean: bool,

    pub fn print(self: Expression) void {
        switch (self) {
            .InfixExpression => |i| {
                std.debug.print("InfixExpression ( left = ", .{});
                i.left.print();
                std.debug.print(", op = ({s})", .{i.op});
                std.debug.print(", right = ", .{});
                i.right.print();
                std.debug.print(" ),", .{});
            },
            .Identifier => |i| std.debug.print("Identifier({s})", .{i}),
            .String => |i| std.debug.print("String({s})", .{i}),
            .Number => |i| {
                std.debug.print("Number(", .{});
                i.print();
                std.debug.print(")", .{});
            },
            .Boolean => |i| std.debug.print("Boolean({any})", .{i}),
            .ColumnDDL => |i| {
                std.debug.print("{s}: ", .{i.name});
                i.dtype.print();
            },
            .Rows => |row| {
                for (row.items) |r| {
                    r.print();
                    std.debug.print(", ", .{});
                }
            },
            .ProjectClause => |clause| {
                for (clause.items) |p| {
                    p.print();
                    std.debug.print(", ", .{});
                }
            },
            .RenameClause => |r| {
                r.from.print();
                std.debug.print(" -> ", .{});
                r.to.print();
            },
            .ForeignKey => |f| {
                f.column.print();
                std.debug.print(" -> ", .{});
                f.table.print();
            },
            else => std.debug.print("null", .{}),
        }
    }
};

pub const Precedence = enum(u8) {
    Lowest = 1,
    Equals = 2,
    LessGreater = 3,
    Sum = 4,
    Product = 5,
    Prefix = 6,
    Call = 7,
    Index = 8,

    pub fn get(token_type: TokenType) ?Precedence {
        return switch (token_type) {
            .Equality, .Equal, .NotEqual => Precedence.Equals,
            .LessThan => Precedence.LessGreater,
            .GreaterThan => Precedence.LessGreater,
            .Plus, .Dash => Precedence.Sum,
            .Slash, .Asterisk, .Ampersand, .NaturalJoin => Precedence.Product,
            .Lparen, .Period => Precedence.Call,
            .Lbracket => Precedence.Index,
            else => null,
        };
    }
};

pub const Prefix = enum {
    Identifier,
    Number,
    Float,
    Boolean,
    String,
    Assign,
    Other,
    If,
    Grouped,

    pub fn get(token_type: TokenType) ?Prefix {
        return switch (token_type) {
            .Identifier => Prefix.Identifier,
            .Number => Prefix.Number,
            .Float => Prefix.Float,
            .String => Prefix.String,
            // .If => Prefix.If,
            .Boolean, .True, .False => Prefix.Boolean,
            .Lparen => Prefix.Grouped,
            else => null,
        };
    }
};

pub const Infix = enum {
    Standard,
    // Call,
    // Index,

    pub fn get(token_type: TokenType) ?Infix {
        return switch (token_type) {
            .Plus => Infix.Standard, // Union
            .Dash => Infix.Standard, // Difference
            .Slash => Infix.Standard, // Division
            .Asterisk => Infix.Standard, // Cartesian Product
            .Ampersand => Infix.Standard, // Intersection
            .NaturalJoin => Infix.Standard,
            .Equality => Infix.Standard,
            .Equal => Infix.Standard,
            .NotEqual => Infix.Standard,
            .LessThan => Infix.Standard,
            .GreaterThan => Infix.Standard,
            // .Lparen => Infix.Call,
            // .Lbracket => Infix.Index,
            else => null,
        };
    }
};
