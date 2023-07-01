const std = @import("std");

const _token = @import("token.zig");
const Token = _token.Token;
const TokenList = _token.TokenList;

const Self = @This();

allocator: std.mem.Allocator,
src: []const u8,
index: usize = 0,

pub fn init(allocator: std.mem.Allocator, src: []const u8) Self {
    return Self {
        .allocator = allocator,
        .src = src
    };
}

fn getCurrent(self: *const Self) u8 {
    if (self.index >= self.src.len) return 0;
    return self.src[self.index];
}

fn advance(self: *Self) void {
    self.index += 1;
}

fn makeNumber(self: *Self) Token {
    var buffer = std.ArrayList(u8).init(self.allocator);
    defer buffer.deinit();

    var current = self.getCurrent();
    while (std.ascii.isDigit(current) or current == '.') {
        buffer.append(current) catch unreachable;
        self.advance();
        current = self.getCurrent();
    } 

    return Token {
        .Number = std.fmt.parseFloat(f64, buffer.items) catch unreachable
    };
}

fn makeId(self: *Self) Token {
    var buffer = std.ArrayList(u8).init(self.allocator);
    defer buffer.deinit();

    var current = self.getCurrent();
    while (std.ascii.isAlphanumeric(current) or current == '_') {
        buffer.append(current) catch unreachable;
        self.advance();
        current = self.getCurrent();
    } 

    return Token {
        .Identifier = buffer.toOwnedSlice() catch unreachable,
    };
}

pub fn tokenize(self: *Self) TokenList {
    var tokens = TokenList.init(self.allocator);

    while (true) {
        const current = self.getCurrent();

        if (std.ascii.isAlphabetic(current)) {
            tokens.append(self.makeId()) catch unreachable;
        } else if (std.ascii.isDigit(current)) {
            tokens.append(self.makeNumber()) catch unreachable;
        } else {
            switch (current) {
                '+' => tokens.append(Token.Plus) catch unreachable,
                '-' => tokens.append(Token.Dash) catch unreachable,
                '*' => tokens.append(Token.Star) catch unreachable,
                '/' => tokens.append(Token.Slash) catch unreachable,
                '(' => tokens.append(Token.LeftParenthesis) catch unreachable,
                ')' => tokens.append(Token.RightParenthesis) catch unreachable,
                '=' => tokens.append(Token.Equal) catch unreachable,
                ',' => tokens.append(Token.Comma) catch unreachable,
                ' ', '\t', '\n' => {
                    // Ignored
                },
                0 => break,
                else => unreachable
            }
            self.advance();
        }
    }

    return tokens;
}