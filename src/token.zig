const std = @import("std");

pub const TokenTag = enum {
    Number,
    Identifier,
    Plus,
    Dash,
    Star,
    Slash,
    LeftParenthesis,
    RightParenthesis,
    Comma,
    Equal,
};

pub const Token = union(TokenTag) {
    Number: f64,
    Identifier: []const u8,
    Plus,
    Dash,
    Star, 
    Slash,
    LeftParenthesis,
    RightParenthesis,
    Comma,
    Equal,

    pub fn deinit(self: *const Token, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .Identifier => |id| allocator.free(id),
            else => {}
        }
    }
};

pub const TokenList = std.ArrayList(Token);