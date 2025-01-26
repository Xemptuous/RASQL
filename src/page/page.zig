const std = @import("std");

pub const PAGE_SIZE: usize = 4096;

pub const Page = struct {
    data: [PAGE_SIZE]u8,
    number: usize,

    pub fn init() Page {
        return Page{
            .data = .{0} ** PAGE_SIZE,
            .number = 0,
        };
    }

    pub fn advancePage(self: *Page) void {
        @memset(&self.data, 0);
        self.number += 1;
    }
};
