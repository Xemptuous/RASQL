const std = @import("std");

pub const TokenType = enum {
    // Keywords
    Database,
    Schema,
    Relation,
    Index,
    Define,
    Return,
    PrimaryKey,
    ForeignKey,
    Create,
    Delete,
    // Chars
    Bang, // !
    At, // @
    Hashtag, // #
    Dollar, // $
    Percent, // %
    Caret, // ^
    Ampersand, // &
    Asterisk, // *
    Underscore, // _
    Dash, // -
    Plus, // +
    Equal, // =
    Semicolon, // ;
    Colon, // :
    Apostrophe, // '
    Quote, // "
    LessThan, // <
    GreaterThan, // >
    Comma, // ,
    Period, // .
    Question, // ?
    Slash, // /
    Pipe, // |
    Backslash, // \
    Lparen, // (
    Rparen, // )
    Lbracket, // [
    Rbracket, // ]
    Lbrace, // {
    Rbrace, // }
    Equality, // ==
    NotEqual, // !=
    Comment, // //

    // Relational
    Select, // S:
    From, // F:
    Project, // P:
    Rename, // R:
    Group, // G:
    Limit, // L:
    Assign, // :=
    SingleArrow, // ->
    DoubleArrow, // =>

    // Joins
    NaturalJoin, // ><
    ThetaJoin, // []
    LeftSemiJoin, // <<
    RightSemiJoin, // >>
    LeftOuterJoin, // <|
    RightOuterJoin, // |>
    FullOuterJoin, // <>
    AntiJoin, // !>

    Identifier,

    // Datatypes
    I8,
    U8,
    I16,
    U16,
    I32,
    U32,
    I64,
    U64,
    F32,
    F64,
    Decimal,
    String,
    Date,
    Timestamp,
    Boolean,
    True,
    False,
    UUID,
    JSON,

    And,
    Or,

    Float,
    Number,

    // Other
    Illegal,
    EOF,
};

pub const Token = struct {
    literal: []const u8,
    type: TokenType,

    pub fn init(literal: []const u8, ttype: TokenType) Token {
        return .{ .literal = literal, .type = ttype };
    }

    pub fn print(self: Token) void {
        std.debug.print("Token( literal: `{s}`, type: {?} )\n", .{ self.literal, self.type });
    }
};

pub const KEYWORDS = std.StaticStringMap(TokenType).initComptime(.{
    .{ "S:", .Select },
    .{ "F:", .From },
    .{ "P:", .Project },
    .{ "R:", .Rename },
    .{ "G:", .Group },
    .{ "L:", .Limit },
    .{ "i8", .I8 },
    .{ "i16", .I16 },
    .{ "i32", .I32 },
    .{ "i64", .I64 },
    .{ "u8", .U8 },
    .{ "u16", .U16 },
    .{ "u32", .U32 },
    .{ "u64", .U64 },
    .{ "f32", .F32 },
    .{ "f64", .F64 },
    .{ "dec", .Decimal },
    .{ "str", .String },
    .{ "dt", .Date },
    .{ "ts", .Timestamp },
    .{ "bool", .Boolean },
    .{ "true", .True },
    .{ "false", .False },
    .{ "uuid", .UUID },
    .{ "json", .JSON },
    .{ "pk", .PrimaryKey },
    .{ "fk", .ForeignKey },
    .{ "create", .Create },
    .{ "delete", .Delete },
    .{ "database", .Database },
    .{ "schema", .Schema },
    .{ "relation", .Relation },
    .{ "index", .Index },
    .{ "define", .Define },
    .{ "return", .Return },
});
