const std = @import("std");

const _node = @import("node.zig");
const Node = _node.Node;
const BinOpNode = _node.BinOpNode;
const NumberNode = _node.NumberNode;
const SymbolCallNode = _node.SymbolCallNode;
const FunCallNode = _node.FunCallNode;

const _token = @import("token.zig");
const TokenList = _token.TokenList;
const Token = _token.Token;

const Self = @This();

allocator: std.mem.Allocator,
tokens: TokenList,
index: usize = 0,

pub fn init(allocator: std.mem.Allocator, tokens: TokenList) Self {
    return Self {
        .allocator = allocator,
        .tokens = tokens
    };
}

fn getCurrent(self: *const Self) ?Token {
    if (self.index >= self.tokens.items.len) return null;
    return self.tokens.items[self.index];
} 

fn peek(self: *const Self, offset: usize) ?Token {
    if (self.index + offset >= self.tokens.items.len) return null;
    return self.tokens.items[self.index + offset];
} 

fn advance(self: *Self) void {
    self.index += 1;
}

fn advanceX(self: *Self, x: usize) void {
    self.index += x;
}

fn parseValue(self: *Self) Node {
    switch (self.getCurrent().?) {
        .Number => |value| return Node {
            .Number = NumberNode {
                .value = value
            }
        },
        .Identifier => |value| {
            if (self.peek(1)) |next| {
                if (next == .LeftParenthesis) {
                    self.advanceX(2);
                    var parameters = std.ArrayList(Node).init(self.allocator);
                    var current = self.getCurrent();
                    var first = true;
                    while (current.? != .RightParenthesis) {
                        if (!first) {
                            if (current.? != .Comma) unreachable;
                            self.advance();
                        }
                        parameters.append(self.parseExpr()) catch unreachable;
                        current = self.getCurrent();
                        first = false;
                    }

                    return Node {
                        .FunCall = FunCallNode {
                            .value = self.allocator.dupe(u8, value) catch unreachable,
                            .parameters = parameters
                        }
                    };
                }
            } 
            // Symbol Call
            return Node {
                .SymbolCall = SymbolCallNode {
                    .value = self.allocator.dupe(u8, value) catch unreachable
                }
            };
        },
        .LeftParenthesis => {
            self.advance();
            const expr = self.parseExpr();
            if (self.getCurrent().? != .RightParenthesis) unreachable;
            return expr;
        },
        else => unreachable
    }
}

fn parseExpr0(self: *Self) Node {
    var lhs = self.parseValue();
    self.advance();

    while (true) {
        if (self.getCurrent() == null) break;
        var operator: BinOpNode.Operator = undefined;
        switch (self.getCurrent().?) {
            .Equal => operator = BinOpNode.Operator.Assign,
            else => break,
        }
        self.advance();

        var rhs_alloc = self.allocator.create(Node) catch unreachable;
        rhs_alloc.* = self.parseExpr();
        var lhs_alloc = self.allocator.create(Node) catch unreachable;
        lhs_alloc.* = lhs;
        lhs = Node {
            .BinOp = BinOpNode {
                .lhs = lhs_alloc,
                .op = operator,
                .rhs = rhs_alloc
            }
        };
    }

    return lhs;
}

fn parseExpr1(self: *Self) Node {
    var lhs = self.parseExpr0();

    while (true) {
        if (self.getCurrent() == null) break;
        var operator: BinOpNode.Operator = undefined;
        switch (self.getCurrent().?) {
            .Star => operator = BinOpNode.Operator.Mul,
            .Slash => operator = BinOpNode.Operator.Div,
            else => break,
        }
        self.advance();

        var rhs_alloc = self.allocator.create(Node) catch unreachable;
        rhs_alloc.* = self.parseExpr0();
        var lhs_alloc = self.allocator.create(Node) catch unreachable;
        lhs_alloc.* = lhs;
        lhs = Node {
            .BinOp = BinOpNode {
                .lhs = lhs_alloc,
                .op = operator,
                .rhs = rhs_alloc
            }
        };
    }

    return lhs;
}

fn parseExpr2(self: *Self) Node {
    var lhs = self.parseExpr1();

    while (true) {
        if (self.getCurrent() == null) break;
        var operator: BinOpNode.Operator = undefined;
        switch (self.getCurrent().?) {
            .Plus => operator = BinOpNode.Operator.Add,
            .Dash => operator = BinOpNode.Operator.Sub,
            else => break,
        }
        self.advance();

        var rhs_alloc = self.allocator.create(Node) catch unreachable;
        rhs_alloc.* = self.parseExpr1();
        var lhs_alloc = self.allocator.create(Node) catch unreachable;
        lhs_alloc.* = lhs;
        lhs = Node {
            .BinOp = BinOpNode {
                .lhs = lhs_alloc,
                .op = operator,
                .rhs = rhs_alloc
            }
        };
    }

    return lhs;
}

const parseExpr = parseExpr2;

pub fn parse(self: *Self) Node {
    if (self.getCurrent()) |current| {
        switch (current) {
            .Number, .Identifier, .LeftParenthesis => return self.parseExpr(),
            else => unreachable,
        }
    } else {
        unreachable;
    } 
}