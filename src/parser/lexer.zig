const std = @import("std");
const token = @import("token.zig");
const Allocator = std.mem.Allocator;
const Token = token.Token;
const TokenType = token.TokenType;
const KEYWORDS = token.KEYWORDS;

const NumberPair = struct {
    str: []const u8,
    ttype: TokenType,
};

fn numberPair(str: []const u8, ttype: TokenType) NumberPair {
    return .{ str, ttype };
}

pub const Lexer = struct {
    input: []const u8,
    curr: usize,
    peek_pos: usize,
    char: ?u8,
    gpa: Allocator,

    pub fn init(input: []const u8, gpa: Allocator) !*Lexer {
        const lexer = try gpa.create(Lexer);
        lexer.* = .{
            .input = input,
            .curr = 0,
            .peek_pos = 0,
            .char = input[0],
            .gpa = gpa,
        };
        lexer.read();
        return lexer;
    }

    pub fn nextToken(self: *Lexer) !Token {
        while (self.char != null and std.ascii.isWhitespace(self.char.?))
            self.read();

        if (self.char == null)
            return Token.init("", TokenType.EOF);

        const ch = self.input[self.curr..self.peek_pos];
        var pair: []const u8 = "";
        if (self.peek_pos < self.input.len) {
            pair = self.input[self.curr .. self.peek_pos + 1];
        }

        var read_next = true;
        const tok = switch (self.char.?) {
            '!' => switch (self.peek().?) {
                '=' => self.pairAndAdvance(pair, .NotEqual),
                '>' => self.pairAndAdvance(pair, .AntiJoin),
                else => Token.init(ch, .Bang),
            },
            '@' => Token.init(ch, .At),
            '#' => Token.init(ch, .Hashtag),
            '$' => Token.init(ch, .Dollar),
            '%' => Token.init(ch, .Percent),
            '^' => Token.init(ch, .Caret),
            '&' => switch (self.peek().?) {
                '&' => self.pairAndAdvance(pair, .And),
                else => Token.init(ch, .Ampersand),
            },
            '*' => Token.init(ch, .Asterisk),
            '_' => Token.init(ch, .Underscore),
            '-' => switch (self.peek().?) {
                '>' => self.pairAndAdvance(pair, .SingleArrow),
                else => Token.init(ch, .Dash),
            },
            '+' => Token.init(ch, .Plus),
            '=' => switch (self.peek().?) {
                '=' => self.pairAndAdvance(pair, .Equality),
                '>' => self.pairAndAdvance(pair, .DoubleArrow),
                else => Token.init(ch, .Equal),
            },
            ';' => Token.init(ch, .Semicolon),
            ':' => switch (self.peek().?) {
                '=' => self.pairAndAdvance(pair, .Assign),
                else => Token.init(ch, .Colon),
            },
            '\'' => Token.init(self.readString(), .String),
            '"' => Token.init(ch, .Quote),
            '<' => switch (self.peek().?) {
                '<' => self.pairAndAdvance(pair, .LeftSemiJoin),
                // '|' => self.pairAndAdvance(pair, .LeftOuterJoin),
                // '>' => self.pairAndAdvance(pair, .FullOuterJoin),
                else => Token.init(ch, .LessThan),
            },
            '>' => switch (self.peek().?) {
                '<' => self.pairAndAdvance(pair, .NaturalJoin),
                '>' => self.pairAndAdvance(pair, .RightSemiJoin),
                else => Token.init(ch, .GreaterThan),
            },
            ',' => Token.init(ch, .Comma),
            '.' => Token.init(ch, .Period),
            '?' => Token.init(ch, .Question),
            '/' => switch (self.peek().?) {
                '/' => {
                    const str = self.readComment();
                    return Token.init(str, .Comment);
                },
                else => Token.init(ch, .Slash),
            },
            '|' => switch (self.peek().?) {
                '|' => self.pairAndAdvance(pair, .Or),
                // '>' => self.pairAndAdvance(pair, .RightOuterJoin),
                else => Token.init(ch, .Pipe),
            },
            '\\' => Token.init(ch, .Backslash),
            '(' => Token.init(ch, .Lparen),
            ')' => Token.init(ch, .Rparen),
            '[' => switch (self.peek().?) {
                ']' => self.pairAndAdvance(pair, .ThetaJoin),
                else => Token.init(ch, .Lbracket),
            },
            ']' => Token.init(ch, .Rbracket),
            '{' => Token.init(ch, .Lbrace),
            '}' => Token.init(ch, .Rbrace),
            '0'...'9' => {
                read_next = false;
                const res = self.readNumber();
                return Token.init(res.str, res.ttype);
            },
            'A'...'Z', 'a'...'z' => {
                read_next = false;
                const p = self.peek();
                if (p == null) return Token.init(" ", .EOF);
                if (p.? == ':') {
                    const ident = pair;
                    self.read();
                    self.read();
                    const keyword = KEYWORDS.get(ident);
                    if (keyword == null)
                        return Token.init(ident, .Identifier);
                    return Token.init(ident, keyword.?);
                } else {
                    const ident = self.readIdentifier();
                    var lower_buf = [_]u8{0} ** 100;
                    const lower = std.ascii.lowerString(&lower_buf, ident);
                    const keyword = KEYWORDS.get(lower);
                    if (keyword == null)
                        return Token.init(ident, .Identifier);
                    return Token.init(ident, keyword.?);
                }
            },
            else => Token.init("ILLEGAL", .Illegal),
        };
        if (read_next) self.read();
        return tok;
    }

    fn pairAndAdvance(self: *Lexer, pair: []const u8, ttype: TokenType) Token {
        self.read();
        self.read();
        return Token.init(pair, ttype);
    }

    fn readString(self: *Lexer) []const u8 {
        self.read();
        const pos = self.curr;
        while (self.char != null and self.char.? != '\'') {
            // skip escape quote char
            if (self.char.? == '\\' and self.peek() == '\'') {
                self.read();
                self.read();
                continue;
            }
            self.read();
        }

        const diff = self.curr - pos;
        return self.input[pos .. pos + diff];
    }

    fn readComment(self: *Lexer) []const u8 {
        const pos = self.curr;

        while (self.char != null and self.char.? != '\n') {
            self.read();
        }

        const diff = self.curr - pos;
        return self.input[pos .. pos + diff];
    }

    fn readIdentifier(self: *Lexer) []const u8 {
        const pos = self.curr;

        while (self.char != null and (std.ascii.isAlphanumeric(self.char.?) or self.char.? == '_'))
            self.read();

        const diff = self.curr - pos;
        return self.input[pos .. pos + diff];
    }

    fn readNumber(self: *Lexer) NumberPair {
        const pos = self.curr;
        var is_float = false;

        while (self.char != null and (std.ascii.isDigit(self.char.?) or self.char.? == '.')) {
            if (self.char.? == '.') {
                if (is_float)
                    return .{ .str = "ILLEGAL", .ttype = .Illegal };
                is_float = true;
            }
            self.read();
        }
        const diff = self.curr - pos;
        const str = self.input[pos .. pos + diff];
        if (is_float)
            return .{ .str = str, .ttype = .Float };
        return .{ .str = str, .ttype = .Number };
    }

    fn peek(self: *Lexer) ?u8 {
        if (self.peek_pos <= self.input.len)
            return self.input[self.peek_pos];
        return null;
    }

    fn read(self: *Lexer) void {
        self.curr = self.peek_pos;
        self.peek_pos = self.curr + 1;
        if (self.peek_pos <= self.input.len)
            self.char = self.input[self.curr]
        else
            self.char = null;
    }
};
