const std = @import("std");
const fmt = std.fmt;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Lexer = @import("lexer.zig").Lexer;

const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

const RowValue = @import("../table/row.zig").RowValue;

const expression = @import("expression.zig");
const DataType = expression.DataType;
const Prefix = expression.Prefix;
const Infix = expression.Infix;
const Precedence = expression.Precedence;
const Expression = expression.Expression;
const NumberUnion = expression.NumberUnion;

const Statement = @import("statement.zig").Statement;

pub const ParserError = error{
    PrefixNotFound,
    InfixNotFound,
    InvalidDataType,
    InvalidRelationName,
    InvalidColumnName,
    UnexpectedToken,
    InvalidCharacter,
    ParseInteger,
    ParseIdentifier,
    ParseBoolean,
    NoProjectInReturn,
    MissingIdentifier,
    MissingSemicolon,
    MissingColon,
    MissingSingleArrow,
    MissingFromClause,
    MissingProjectClause,
    MissingClosingApostrophe,
    MissingComma,
    MissingAssignmentOperator,
    MissingLbrace,
    MissingRparen,
    MissingLparen,
    InvalidLimit,
    OutOfMemory,
};

pub const Parser = struct {
    lexer: *Lexer,
    curr: Token,
    peek: Token,
    gpa: Allocator,

    pub fn init(gpa: Allocator, lexer: *Lexer) !*Parser {
        const parser = try gpa.create(Parser);
        parser.* = .{
            .lexer = lexer,
            .curr = undefined,
            .peek = undefined,
            .gpa = gpa,
        };
        try parser.nextToken();
        try parser.nextToken();
        return parser;
    }

    // pub fn parse(self: *Parser) void {}

    pub fn parse(self: *Parser) ParserError!ArrayList(*Statement) {
        var statements = ArrayList(*Statement).init(self.gpa);
        while (self.peek.type != .EOF) {
            std.debug.print("MAIN START: CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
            var stmt: *Statement = undefined;

            if (self.curr.type == .Comment) {
                try self.nextToken();
                continue;
            }

            stmt = switch (self.curr.type) {
                // .Delete => try self.parseDeleteStatement(),
                // .Database => try self.parseDatabaseStatement(),
                .Relation => try self.parseRelationStatement(),
                .Define => try self.parseDefineStatement(),
                .Identifier => if (self.peek.type == .Assign) try self.parseDefineStatement() else try self.parseReturnStatement(),
                .Return => try self.parseReturnStatement(),
                else => try self.parseReturnStatement(),
            };
            std.debug.print("MAIN MID: CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
            if (!self.expect(.Semicolon))
                return ParserError.MissingSemicolon;
            try self.nextToken();
            std.debug.print("MAIN END: CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });

            statements.append(stmt) catch {
                return ParserError.OutOfMemory;
            };
        }
        return statements;
    }

    // fn parseDatabaseStatement(self: *Parser) ParserError!*Statement {}

    fn parseDefineStatement(self: *Parser) ParserError!*Statement {
        std.debug.print("  DEFINE START: CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
        const name = try self.parseIdentifier();
        if (!self.expect(.Assign))
            return ParserError.MissingAssignmentOperator;
        if (!self.expect(.From)) {
            try self.nextToken();
            const expr = try self.parseExpressionStatement();
            std.debug.print("  DEFINE EXPR: CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
            // return ParserError.MissingFromClause;
            const s = try self.gpa.create(Statement);
            s.* = Statement{ .DefineStatement = .{
                .name = name,
                .from = null,
                .project = null,
                .renames = null,
                .select = null,
                .expression = expr,
            } };
            return s;
        }
        try self.nextToken();
        const from = try self.parseIdentifier();
        std.debug.print("  DEFINE MID: CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
        if (!self.expect(.Project))
            return ParserError.MissingProjectClause;
        const columns = try self.parseProjectClause();
        // try self.nextToken();
        var renames: ?ArrayList(*Expression) = null;
        if (self.peek.type == .Rename) {
            renames = try self.parseRenameClause();
        }

        var select: ?ArrayList(*Expression) = undefined;
        std.debug.print("  DEFINE MID2: CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
        if (self.expect(.Select)) {
            std.debug.print("  DEFINE MID PRE SELECT: CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
            select = self.parseSelectStatement() catch |e| return e;
        }

        std.debug.print("  DEFINE END: CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
        const s = try self.gpa.create(Statement);
        s.* = Statement{ .DefineStatement = .{
            .name = name,
            .from = from,
            .project = columns,
            .renames = renames,
            .select = select,
            .expression = null,
        } };
        return s;
    }

    fn parseRenameClause(self: *Parser) ParserError!ArrayList(*Expression) {
        std.debug.print("    RENAME START: CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
        try self.nextToken();
        var renames = ArrayList(*Expression).init(self.gpa);
        while (self.peek.type != .Semicolon and self.peek.type != .Select and self.peek.type != .EOF) {
            try self.nextToken();
            std.debug.print("    CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
            const from = try self.parseIdentifier();
            if (!self.expect(.SingleArrow))
                return ParserError.MissingSingleArrow;
            try self.nextToken();
            const to = try self.parseIdentifier();
            const r = try self.gpa.create(Expression);

            r.* = Expression{ .RenameClause = .{ .from = from, .to = to } };
            try renames.append(r);
        }
        std.debug.print("    RENAME END: CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
        return renames;
    }

    fn parseProjectClause(self: *Parser) ParserError!ArrayList(*Expression) {
        var columns = ArrayList(*Expression).init(self.gpa);
        while (self.peek.type != .Rename and self.peek.type != .Semicolon and self.peek.type != .EOF) {
            try self.nextToken();
            const name = try self.parseIdentifier();
            try columns.append(name);
            if (self.peek.type == .Rename or self.peek.type == .Select or self.peek.type == .Semicolon) {
                break;
            }
            if (!self.expect(.Comma))
                return ParserError.MissingComma;
        }
        return columns;
    }

    fn parseRelationStatement(self: *Parser) ParserError!*Statement {
        if (!self.expect(.Identifier))
            return ParserError.MissingIdentifier;
        const stmt = switch (self.peek.type) {
            .Assign => try self.parseCreateRelationStatement(),
            .Plus => try self.parseUnionRelationStatement(),
            else => return ParserError.InvalidCharacter,
        };
        return stmt;
    }

    fn parseUnionRelationStatement(self: *Parser) ParserError!*Statement {
        const name = try self.parseIdentifier();
        if (!self.expect(.Plus))
            return ParserError.InvalidCharacter;
        if (!self.expect(.Lbrace))
            return ParserError.MissingLbrace;

        var rows = ArrayList(*Expression).init(self.gpa);
        while (self.curr.type != .Rbrace and self.curr.type != .EOF) {
            std.debug.print("  START CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
            if (self.peek.type == .Comment) {
                try self.nextToken();
                continue;
            }
            if (!self.expect(.Lparen))
                return ParserError.MissingLparen;
            try self.nextToken();
            const row = try self.parseRowValues();
            rows.append(row) catch
                return ParserError.OutOfMemory;
            std.debug.print("  PRE-BREAK CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
            if (self.curr.type != .Comma and self.peek.type == .Rbrace) {
                try self.nextToken();
                break;
            }
            std.debug.print("  END CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
        }
        if (self.curr.type == .Comma and self.peek.type == .Rbrace)
            try self.nextToken();
        const s = try self.gpa.create(Statement);
        s.* = Statement{ .UnionRelation = .{ .left = name, .rows = rows } };
        return s;
    }

    fn parseCreateRelationStatement(self: *Parser) ParserError!*Statement {
        if (self.curr.type != .Identifier)
            return ParserError.InvalidRelationName;
        const relation_name = self.curr.literal;

        // advance past assign
        try self.nextToken();
        try self.nextToken();

        var columns = ArrayList(*Expression).init(self.gpa);
        var pks = ArrayList(*Expression).init(self.gpa);
        var fks = ArrayList(*Expression).init(self.gpa);
        while (self.curr.type != .Semicolon and self.curr.type != .EOF) {
            if (self.curr.type == .PrimaryKey) {
                std.debug.print("PRIMARY KEY\n", .{});
                if (!self.expect(.Colon))
                    return ParserError.MissingColon;
                try self.nextToken();
                pks = try self.parseRelationPrimaryKeys();
            } else if (self.curr.type == .ForeignKey) {
                std.debug.print("FOREIGN KEY\n", .{});
                if (!self.expect(.Colon))
                    return ParserError.MissingColon;
                if (!self.expect(.Identifier))
                    return ParserError.MissingIdentifier;
                const fk = try self.parseRelationForeignKey();
                try fks.append(fk);
            } else {
                std.debug.print("COLUMN\n", .{});
                const expr = try self.parseColumnDDLExpression();
                try columns.append(expr);
            }

            std.debug.print("RELATION LOOP CURR: {?}  PEEK: {?}\n", .{ self.curr.type, self.peek.type });

            if (self.peek.type == .Semicolon)
                break;
            if (!self.expect(.Comma))
                return ParserError.MissingComma;
            try self.nextToken();
        }

        const rel = try self.gpa.create(Statement);
        rel.* = .{ .CreateRelation = .{
            .name = relation_name,
            .primary_keys = pks,
            .foreign_keys = fks,
            .columns = columns,
        } };
        return rel;
    }

    fn parseRelationPrimaryKeys(self: *Parser) ParserError!ArrayList(*Expression) {
        var pks = ArrayList(*Expression).init(self.gpa);
        switch (self.curr.type) {
            .Lparen => {
                while (self.peek.type != .Rparen or self.peek.type != .EOF) {
                    try self.nextToken();
                    if (self.curr.type == .Rparen) break;
                    if (self.curr.type != .Identifier)
                        return ParserError.InvalidColumnName;
                    const name = try self.parseIdentifier();
                    if (!self.expect(.Comma) and self.peek.type != .Rparen)
                        return ParserError.MissingComma;
                    try pks.append(name);
                }
            },
            .Identifier => {
                const ident = try self.parseIdentifier();
                try pks.append(ident);
            },
            else => return ParserError.MissingIdentifier,
        }
        return pks;
    }

    fn parseRelationForeignKey(self: *Parser) ParserError!*Expression {
        std.debug.print("FK CURR: {?}  PEEK: {?}\n", .{ self.curr.type, self.peek.type });
        const column = try self.parseIdentifier();

        if (!self.expect(.SingleArrow))
            return ParserError.MissingSingleArrow;

        if (!self.expect(.Identifier))
            return ParserError.MissingIdentifier;
        const table = try self.parseIdentifier();

        const e = try self.gpa.create(Expression);
        e.* = .{ .ForeignKey = .{
            .column = column,
            .table = table,
        } };
        return e;
    }

    fn parseColumnDDLExpression(self: *Parser) ParserError!*Expression {
        const dtype: DataType = switch (self.curr.type) {
            .I8 => .Int8,
            .I16 => .Int16,
            .I32 => .Int32,
            .I64 => .Int64,
            .U8 => .Uint8,
            .U16 => .Uint16,
            .U32 => .Uint32,
            .U64 => .Uint64,
            .F32 => .Float32,
            .F64 => .Float64,
            .String => .String,
            .Date => .Date,
            .Timestamp => .Timestamp,
            .Boolean => .Boolean,
            else => return ParserError.InvalidDataType,
        };

        if (!self.expect(.Colon))
            return ParserError.MissingColon;
        try self.nextToken();

        if (self.curr.type != .Identifier)
            return ParserError.InvalidColumnName;
        const name = self.curr.literal;

        // if (!self.expect(.Comma) and self.peek.type != .Rparen)
        //     return ParserError.MissingComma;
        // try self.nextToken();
        const expr = try self.gpa.create(Expression);
        expr.* = .{ .ColumnDDL = .{ .dtype = dtype, .name = name } };
        return expr;
    }

    fn parseReturnStatement(self: *Parser) ParserError!*Statement {
        // Bare expression from RETURN
        if (!self.expect(.From)) {
            try self.nextToken();
            return try self.parseExpressionStatement();
        }
        try self.nextToken();
        const table = try self.parseIdentifier();

        if (!self.expect(.Project)) {
            return ParserError.NoProjectInReturn;
        }

        try self.nextToken();
        const columns = self.parseProjectColumns() catch |e| return e;

        var select: ?ArrayList(*Expression) = undefined;
        if (self.expect(.Select)) {
            select = self.parseSelectStatement() catch |e| return e;
        }

        var limit: ?*Expression = undefined;
        if (self.expect(.Limit)) {
            limit = self.parseLimitStatement() catch |e| return e;
        }
        const s = self.gpa.create(Statement) catch {
            return ParserError.OutOfMemory;
        };
        s.* = Statement{ .Return = .{
            .from = table,
            .project = columns,
            .limit = limit,
            .select = select,
        } };
        return s;
    }

    fn parseExpression(self: *Parser, precedence: Precedence) ParserError!*Expression {
        std.debug.print("PREFIX TOK: {?}\n", .{self.curr.type});
        const prefix = Prefix.get(self.curr.type);
        if (prefix == null) {
            return ParserError.PrefixNotFound;
        }
        std.debug.print("  PREFIX: {?}\n", .{self.curr.type});
        var left: *Expression = switch (prefix.?) {
            Prefix.Identifier => try self.parseIdentifier(),
            Prefix.Number => try self.parseNumber(),
            Prefix.Boolean => try self.parseBoolean(),
            Prefix.String => try self.parseIdentifier(),
            Prefix.Grouped => try self.parseGroupedExpression(),
            else => return ParserError.PrefixNotFound,
        };

        while ((self.peek.type != .Semicolon or self.peek.type != .Limit) and
            @intFromEnum(precedence) < @intFromEnum(self.peekPrecedence()))
        {
            const infix = Infix.get(self.peek.type);
            std.debug.print("    INFIX TOK: {?}\n", .{self.curr.type});
            if (infix == null) return ParserError.InfixNotFound;
            try self.nextToken();

            left = switch (infix.?) {
                Infix.Standard => try self.parseInfixExpression(left),
                Infix.Call => try self.parseCallExpression(left),
                else => try self.parseInfixExpression(left),
                // Infix.Index => self.parseIndexExpression(left),
            };
        }
        return left;
    }

    fn parseExpressionStatement(self: *Parser) ParserError!*Statement {
        const expr = try self.parseExpression(Precedence.Lowest);
        const s = self.gpa.create(Statement) catch {
            return ParserError.OutOfMemory;
        };
        s.* = Statement{ .ExpressionStatement = .{ .expression = expr } };
        return s;
    }

    fn parseInfixExpression(self: *Parser, left: *Expression) ParserError!*Expression {
        const precedence = self.currPrecedence();
        const op = self.curr.literal;
        try self.nextToken();
        const right = try self.parseExpression(precedence);

        const e = self.gpa.create(Expression) catch {
            return ParserError.OutOfMemory;
        };
        e.* = Expression{ .Infix = .{
            .left = left,
            .op = op,
            .right = right,
        } };
        return e;
    }

    fn parseCallExpression(self: *Parser, func: *Expression) ParserError!*Expression {
        const args = try self.parseExpressionList(.Rparen);
        const e = try self.gpa.create(Expression);
        e.* = .{ .Call = .{ .func = func, .args = args } };
        return e;
    }

    fn parseExpressionList(self: *Parser, end: TokenType) ParserError!ArrayList(*Expression) {
        var list = ArrayList(*Expression).init(self.gpa);
        if (self.peek.type == end) {
            try self.nextToken();
            return list;
        }

        try self.nextToken();
        try list.append(try self.parseExpression(.Lowest));

        while (self.peek.type == .Comma) {
            try self.nextToken();
            try self.nextToken();
            try list.append(try self.parseExpression(.Lowest));
        }

        if (!self.expect(end))
            return ParserError.MissingRparen;
        return list;
    }

    fn parseProjectColumns(self: *Parser) ParserError!ArrayList(*Expression) {
        var columns = ArrayList(*Expression).init(self.gpa);

        columns.append(try self.parseIdentifier()) catch {
            return ParserError.OutOfMemory;
        };

        while (self.peek.type == .Comma) {
            try self.nextToken();
            switch (self.peek.type) {
                .Semicolon, .Limit, .Rename, .Select => break,
                else => {},
            }
            try self.nextToken();
            columns.append(try self.parseIdentifier()) catch {
                return ParserError.OutOfMemory;
            };
        }
        return columns;
    }

    fn parseSelectStatement(self: *Parser) ParserError!?ArrayList(*Expression) {
        try self.nextToken();
        var clauses = ArrayList(*Expression).init(self.gpa);
        while (self.peek.type != .Semicolon and self.peek.type != .Limit) {
            std.debug.print("      SELECT START CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
            std.debug.print("      SELECT MID CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
            const expr = self.parseExpression(Precedence.Lowest) catch |e| return e;
            std.debug.print("      SELECT POST CURR: {?} PEEK: {?}\n", .{ self.curr.type, self.peek.type });
            try clauses.append(expr);
            if (self.peek.type == .And or self.peek.type == .Or) {
                try self.nextToken();
                try self.nextToken();
            }
        }
        return if (clauses.items.len == 0) null else clauses;
    }

    fn parseLimitStatement(self: *Parser) ParserError!?*Expression {
        if (self.curr.type == .Limit) {
            if (!self.expect(.Number))
                return ParserError.InvalidLimit;
            return self.parseNumber() catch |e| {
                std.debug.print("ERR: {?}\n", .{e});
                return ParserError.InvalidLimit;
            };
        }
        return null;
    }

    fn parseRowValues(self: *Parser) ParserError!*Expression {
        var rows = ArrayList(*Expression).init(self.gpa);
        while (self.peek.type != .Rbrace and self.peek.type != .EOF) {
            if (self.peek.type == .Comment) {
                try self.nextToken();
                continue;
            }
            std.debug.print("CURR: {?}\n", .{self.curr.type});
            const row = switch (self.curr.type) {
                .String => try self.parseString(),
                .Number, .Float => try self.parseNumber(),
                .True, .False => try self.parseBoolean(),
                else => return ParserError.UnexpectedToken,
            };
            rows.append(row) catch
                return ParserError.OutOfMemory;

            if (self.peek.type == .Comma)
                try self.nextToken();
            try self.nextToken();
            if (self.curr.type == .Rparen)
                break;
        }
        if (self.curr.type != .Rparen)
            return ParserError.MissingRparen;
        try self.nextToken();
        const r = self.gpa.create(Expression) catch
            return ParserError.OutOfMemory;
        r.* = Expression{ .Rows = rows };
        return r;
    }

    fn parseGroupedExpression(self: *Parser) ParserError!*Expression {
        try self.nextToken();
        const e = self.parseExpression(.Lowest);
        if (!self.expect(.Rparen))
            return ParserError.MissingRparen;
        return e;
    }

    fn parseString(self: *Parser) ParserError!*Expression {
        const e = self.gpa.create(Expression) catch {
            return ParserError.OutOfMemory;
        };
        e.* = Expression{ .String = self.curr.literal };
        return e;
    }

    fn parseIdentifier(self: *Parser) ParserError!*Expression {
        const e = self.gpa.create(Expression) catch {
            return ParserError.OutOfMemory;
        };
        e.* = Expression{ .Identifier = self.curr.literal };
        return e;
    }

    fn parseBoolean(self: *Parser) ParserError!*Expression {
        var outstr = [_]u8{0} ** 5;
        const lower = std.ascii.lowerString(&outstr, self.curr.literal);
        const e = self.gpa.create(Expression) catch {
            return ParserError.OutOfMemory;
        };
        if (std.mem.eql(u8, lower, "true")) {
            e.* = Expression{ .Boolean = true };
            return e;
        } else if (std.mem.eql(u8, lower, "false")) {
            e.* = Expression{ .Boolean = false };
            return e;
        } else {
            return ParserError.ParseBoolean;
        }
    }

    fn parseNumberType(self: *Parser) fmt.ParseIntError!NumberUnion {
        return switch (self.curr.type) {
            .I8 => NumberUnion{ .Int8 = try fmt.parseInt(i8, self.curr.literal, 10) },
            .I16 => NumberUnion{ .Int16 = try fmt.parseInt(i16, self.curr.literal, 10) },
            .I32 => NumberUnion{ .Int32 = try fmt.parseInt(i32, self.curr.literal, 10) },
            .I64 => NumberUnion{ .Int64 = try fmt.parseInt(i64, self.curr.literal, 10) },
            .U8 => NumberUnion{ .Uint8 = try fmt.parseUnsigned(u8, self.curr.literal, 10) },
            .U16 => NumberUnion{ .Uint16 = try fmt.parseUnsigned(u16, self.curr.literal, 10) },
            .U32 => NumberUnion{ .Uint32 = try fmt.parseUnsigned(u32, self.curr.literal, 10) },
            .U64 => NumberUnion{ .Uint64 = try fmt.parseUnsigned(u64, self.curr.literal, 10) },
            .F32 => NumberUnion{ .Float32 = try fmt.parseFloat(f32, self.curr.literal) },
            .F64 => NumberUnion{ .Float64 = try fmt.parseFloat(f64, self.curr.literal) },
            .Float => NumberUnion{ .Float64 = try fmt.parseFloat(f64, self.curr.literal) },
            .Number => NumberUnion{ .Int64 = try fmt.parseInt(i64, self.curr.literal, 10) },
            else => return fmt.ParseIntError.InvalidCharacter,
        };
        // return switch (num_type) {
        //     u8 => Expression.Number{ .Uint8 = try fmt.parseUnsigned(num_type, self.curr, 10) },
        //     u16 => Expression.Number{ .Uint16 = try fmt.parseUnsigned(num_type, self.curr, 10) },
        //     u32 => Expression.Number{ .Uint32 = try fmt.parseUnsigned(num_type, self.curr, 10) },
        //     u64 => Expression.Number{ .Uint64 = try fmt.parseUnsigned(num_type, self.curr, 10) },
        //     i8 => Expression.Number{ .Int8 = try fmt.parseInt(num_type, self.curr, 10) },
        //     i16 => Expression.Number{ .Int16 = try fmt.parseInt(num_type, self.curr, 10) },
        //     i32 => Expression.Number{ .Int32 = try fmt.parseInt(num_type, self.curr, 10) },
        //     i64 => Expression.Number{ .Int64 = try fmt.parseInt(num_type, self.curr, 10) },
        //     f32 => Expression.Number{ .Float32 = try fmt.parseFloat(num_type, self.curr) },
        //     f64 => Expression.Number{ .Float64 = try fmt.parseFloat(num_type, self.curr) },
        //     else => {},
        // };
    }

    fn parseNumber(self: *Parser) ParserError!*Expression {
        const number = self.parseNumberType() catch |e| {
            std.debug.print("ERR: {?}\n", .{e});
            return ParserError.InvalidDataType;
        };
        const e = self.gpa.create(Expression) catch {
            return ParserError.OutOfMemory;
        };
        e.* = Expression{ .Number = number };
        return e;
    }

    fn currPrecedence(self: *Parser) Precedence {
        const p = Precedence.get(self.curr.type);
        if (p == null) return Precedence.Lowest;
        return p.?;
    }

    fn peekPrecedence(self: *Parser) Precedence {
        const p = Precedence.get(self.peek.type);
        if (p == null) return Precedence.Lowest;
        return p.?;
    }

    fn expect(self: *Parser, ttype: TokenType) bool {
        if (self.peek.type == ttype) {
            try self.nextToken();
            return true;
        }
        return false;
    }

    pub fn nextToken(self: *Parser) !void {
        std.mem.swap(Token, &self.curr, &self.peek);
        self.peek = try self.lexer.nextToken();
    }
};
