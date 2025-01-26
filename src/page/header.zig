const std = @import("std");
const ArrayList = std.ArrayList;
const Column = @import("../table/column.zig").Column;
const Table = @import("../table/table.zig").Table;

pub const FileType = enum {
    Data,
    Index,
};

pub const Header = struct {
    type: FileType,
    column_count: usize,
    // number_of_pages: usize,
    // free_pages: []usize,
    // next_available_page: usize,
    column_definitions: *ArrayList(Column),
    // record_count: usize,
};
