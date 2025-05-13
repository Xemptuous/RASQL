const std = @import("std");
const token = @import("token.zig");
const Allocator = std.mem.Allocator;
const Token = token.Token;
const TokenType = token.TokenType;

pub const Lexer = struct {
    input: []const u8,
    curr: usize,
    peek: usize,
    char: u8,

    pub fn init(input: []const u8, gpa: *const Allocator) !*Lexer {
        const lexer = try gpa.create(Lexer);
        lexer.* = .{
            .input = input,
            .curr = 0,
            .peek = 0,
            .char = input[0],
        };
        lexer.advance();
        return lexer;
    }

    pub fn nextToken(self: *Lexer) Token {
        while (std.ascii.isWhitespace(self.char))
            self.advance();

        if (self.peekChar() == 0) {
            return Token.new(.EOF, "\\0");
        }

        const ch = &[_]u8{self.char};
        const next = self.peekChar();
        const tok = switch (self.char) {
            0 => Token.new(.EOF, "\\0"),
            '!' => switch (next) {
                '=' => self.pairAndAdvance(.NotEqual),
                '>' => self.pairAndAdvance(.AntiJoin),
                else => Token.new(.Bang, ch),
            },
            '@' => Token.new(.At, ch),
            '#' => Token.new(.Hashtag, ch),
            '$' => Token.new(.Dollar, ch),
            '%' => Token.new(.Percent, ch),
            '^' => Token.new(.Caret, ch),
            '&' => switch (next) {
                '&' => self.pairAndAdvance(.And),
                else => Token.new(.Ampersand, ch),
            },
            '*' => Token.new(.Asterisk, ch),
            '_' => Token.new(.Underscore, ch),
            '-' => switch (next) {
                '>' => self.pairAndAdvance(.SingleArrow),
                else => Token.new(.Dash, ch),
            },
            '+' => Token.new(.Plus, ch),
            '=' => switch (next) {
                '=' => self.pairAndAdvance(.Equality),
                '>' => self.pairAndAdvance(.DoubleArrow),
                else => Token.new(.Equal, ch),
            },
            ';' => Token.new(.Semicolon, ch),
            ':' => switch (next) {
                '=' => self.pairAndAdvance(.Assign),
                else => Token.new(.Colon, ch),
            },
            '\'' => Token.new(.String, self.readString()),
            '"' => Token.new(.Quote, ch),
            '<' => switch (next) {
                '=' => self.pairAndAdvance(.LessThanEqual),
                '<' => self.pairAndAdvance(.LeftSemiJoin),
                // '>' => self.pairAndAdvance(.FullOuterJoin),
                else => Token.new(.LessThan, ch),
            },
            '>' => switch (next) {
                '=' => self.pairAndAdvance(.GreaterThanEqual),
                '<' => self.pairAndAdvance(.NaturalJoin),
                '>' => self.pairAndAdvance(.RightSemiJoin),
                else => Token.new(.GreaterThan, ch),
            },
            ',' => Token.new(.Comma, ch),
            '.' => Token.new(.Period, ch),
            '?' => Token.new(.Question, ch),
            '/' => switch (next) {
                '/' => Token.new(.Comment, self.readComment()),
                else => Token.new(.Slash, ch),
            },
            '|' => switch (next) {
                '|' => self.pairAndAdvance(.Or),
                '>' => self.pairAndAdvance(.RightOuterJoin),
                else => Token.new(.Pipe, ch),
            },
            '\\' => Token.new(.Backslash, ch),
            '(' => Token.new(.Lparen, ch),
            ')' => Token.new(.Rparen, ch),
            '[' => switch (next) {
                ']' => self.pairAndAdvance(.ThetaJoin),
                else => Token.new(.Lbracket, ch),
            },
            ']' => Token.new(.Rbracket, ch),
            '{' => Token.new(.Lbrace, ch),
            '}' => Token.new(.Rbrace, ch),
            '0'...'9' => return self.readNumber(),
            'a'...'z', 'A'...'Z' => return self.readIdentifier(),
            else => Token.new(.Illegal, "ILLEGAL"),
        };
        self.advance();
        return tok;
    }

    inline fn pairAndAdvance(self: *Lexer, ttype: TokenType) Token {
        const start = self.curr;
        self.advance();
        self.advance();
        return Token.new(ttype, self.input[start..self.curr]);
    }

    inline fn readString(self: *Lexer) []const u8 {
        self.advance();
        const pos = self.curr;
        while (self.char != '\'' and self.char != '\n' and self.char != '\r') {
            // skip escape quote char
            if (self.char == '\\' and self.peekChar() == '\'')
                self.advance();
            self.advance();
        }
        return self.input[pos..self.curr];
    }

    inline fn readComment(self: *Lexer) []const u8 {
        const pos = self.curr;
        while (self.char != '\n' and self.char != '\r')
            self.advance();
        return self.input[pos..self.curr];
    }

    inline fn readIdentifier(self: *Lexer) Token {
        const p = self.peekChar();
        if (p == 0) return Token.new(.EOF, "\\0");
        if (p == ':') {
            const ident = self.input[self.curr .. self.peek + 1];
            self.advance();
            self.advance();
            const tok = switch (ident[0]) {
                'S' => Token.new(.Select, ident),
                'F' => Token.new(.From, ident),
                'P' => Token.new(.Project, ident),
                'R' => Token.new(.Rename, ident),
                'G' => Token.new(.Group, ident),
                'L' => Token.new(.Limit, ident),
                else => Token.new(.Identifier, ident),
            };

            return tok;
        } else {
            var has_upper = false;
            const pos = self.curr;
            while (std.ascii.isAlphanumeric(self.char) or self.char == '_') {
                if (!has_upper and std.ascii.isUpper(self.char))
                    has_upper = true;
                self.advance();
            }
            var ident = self.input[pos..self.curr];
            if (has_upper) {
                var lower_buf = [_]u8{0} ** 100;
                ident = std.ascii.lowerString(&lower_buf, ident);
            }
            if (token.KeywordMap.get(ident)) |k|
                return Token.new(k, ident);
            return Token.new(.Identifier, ident);
        }
    }

    inline fn readNumber(self: *Lexer) Token {
        const pos = self.curr;
        var is_float = false;
        while (std.ascii.isDigit(self.char) or self.char == '.') {
            if (self.char == '.') {
                if (is_float) {
                    self.advance();
                    return Token.new(.Illegal, "ILLEGAL");
                }
                is_float = true;
            }
            self.advance();
        }
        if (is_float)
            return Token.new(.Float, self.input[pos..self.curr]);
        return Token.new(.Number, self.input[pos..self.curr]);
    }

    inline fn peekChar(self: *Lexer) u8 {
        if (self.peek <= self.input.len)
            return self.input[self.peek];
        return 0;
    }

    inline fn advance(self: *Lexer) void {
        if (self.peek >= self.input.len)
            self.char = 0
        else
            self.char = self.input[self.peek];

        self.curr = self.peek;
        self.peek += 1;
    }
};
