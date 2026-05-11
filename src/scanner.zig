const std = @import("std");

pub const TokenType = enum(i32) {
    // Single-character tokens.
    LEFT_PAREN = 1,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,
    // One or two character tokens.
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,
    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,
    // Keywords.
    AND,
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    ERROR,
    EOF,
};

pub const Token = struct {
    type: TokenType,
    start: [*]u8,
    length: i32,
    line: i32,
};

pub const Scanner = struct {
    start: [*]const u8,
    current: [*]const u8,
    end: [*]const u8,
    line: i32,

    const Self = @This();

    pub fn init(source: []const u8) Self {
        return Self{
            .start = source.ptr,
            .current = source.ptr,
            .line = 1,
            .end = source.ptr + source.len,
        };
    }

    pub fn scanToken(self: *Self) Token {
        self.skipWhitespace();

        self.start = self.current;

        if (self.isAtEnd()) return self.makeToken(.EOF);

        const c = self.advance();

        if (isAlpha(c)) return self.scanIdentifier();
        if (isDigit(c)) return self.scanNumber();

        switch (c) {
            '(' => return self.makeToken(.LEFT_PAREN),
            ')' => return self.makeToken(.RIGHT_PAREN),
            '{' => return self.makeToken(.LEFT_BRACE),
            '}' => return self.makeToken(.RIGHT_BRACE),
            ';' => return self.makeToken(.SEMICOLON),
            ',' => return self.makeToken(.COMMA),
            '.' => return self.makeToken(.DOT),
            '-' => return self.makeToken(.MINUS),
            '+' => return self.makeToken(.PLUS),
            '/' => return self.makeToken(.SLASH),
            '*' => return self.makeToken(.STAR),
            '!' => {
                var ttype: TokenType = undefined;

                if (self.peek() == '=') {
                    _ = self.advance();
                    ttype = .BANG_EQUAL;
                } else {
                    ttype = .BANG;
                }

                return self.makeToken(ttype);
            },
            '=' => {
                var ttype: TokenType = undefined;

                if (self.peek() == '=') {
                    _ = self.advance();
                    ttype = .EQUAL_EQUAL;
                } else {
                    ttype = .EQUAL;
                }

                return self.makeToken(ttype);
            },
            '<' => {
                var ttype: TokenType = undefined;

                if (self.peek() == '=') {
                    _ = self.advance();
                    ttype = .LESS_EQUAL;
                } else {
                    ttype = .EQUAL;
                }

                return self.makeToken(ttype);
            },
            '>' => {
                var ttype: TokenType = undefined;

                if (self.peek() == '=') {
                    _ = self.advance();
                    ttype = .GREATER_EQUAL;
                } else {
                    ttype = .GREATER;
                }

                return self.makeToken(ttype);
            },
            '"' => return self.scanString(),
            else => return self.makeErrorToken("Unexpected character."),
        }
    }

    fn isAtEnd(self: *Self) bool {
        return self.current == self.end;
    }

    fn makeToken(self: *Self, tokenType: TokenType) Token {
        return Token{ .type = tokenType, .start = @constCast(self.start), .length = @intCast(self.current - self.start), .line = self.line };
    }

    fn makeErrorToken(self: *Self, message: []const u8) Token {
        return Token{ .type = .ERROR, .start = @constCast(message.ptr), .length = @intCast(message.len), .line = self.line };
    }

    fn advance(self: *Self) u8 {
        self.current += 1;
        return (self.current - 1)[0];
    }

    fn peek(self: *Self) ?u8 {
        if (self.isAtEnd()) {
            return null;
        }

        return self.current[0];
    }

    fn peekNext(self: *Self) ?u8 {
        if (@intFromPtr(self.current) + 1 >= @intFromPtr(self.end)) {
            return null;
        }

        return self.current[1];
    }

    fn skipWhitespace(self: *Self) void {
        while (!self.isAtEnd()) {
            const c = self.peek().?;

            switch (c) {
                ' ', '\r', '\t' => _ = self.advance(),
                '\n' => {
                    self.line += 1;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peekNext() == '/') {
                        while (self.peek() != '\n' and !self.isAtEnd()) {
                            _ = self.advance();
                        }
                    } else {
                        return;
                    }
                },
                else => return,
            }
        }
    }

    fn scanString(self: *Self) Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }

        if (self.isAtEnd()) return self.makeErrorToken("Unterminated string.");

        _ = self.advance();
        return self.makeToken(.STRING);
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
    }

    fn scanNumber(self: *Self) Token {
        while (self.peek() != null and isDigit(self.peek().?)) _ = self.advance();

        if (self.peek() == '.' and self.peekNext() != null and isDigit(self.peekNext().?)) {
            // Consume the dot
            _ = self.advance();

            while (self.peek() != null and isDigit(self.peek().?)) _ = self.advance();
        }

        return self.makeToken(.NUMBER);
    }

    fn scanIdentifier(self: *Self) Token {
        while (self.peek() != null and isAlpha(self.peek().?) or isDigit(self.peek().?)) _ = self.advance();
        return self.makeToken(self.identifierType());
    }

    fn identifierType(self: *Self) TokenType {
        switch (self.start[0]) {
            'a' => return self.checkKeyword(1, 2, "nd", .AND),
            'c' => return self.checkKeyword(1, 4, "lass", .CLASS),
            'e' => return self.checkKeyword(1, 3, "lse", .ELSE),
            'f' => {
                if (self.current - self.start > 1) {
                    switch (self.start[1]) {
                        'a' => return self.checkKeyword(2, 3, "lse", .FALSE),
                        'o' => return self.checkKeyword(2, 1, "r", .FOR),
                        'u' => return self.checkKeyword(2, 1, "n", .FUN),
                        else => return .IDENTIFIER,
                    }
                } else {
                    return .IDENTIFIER;
                }
            },
            'i' => return self.checkKeyword(1, 1, "f", .IF),
            'n' => return self.checkKeyword(1, 2, "il", .NIL),
            'o' => return self.checkKeyword(1, 1, "r", .OR),
            'p' => return self.checkKeyword(1, 4, "rint", .PRINT),
            'r' => return self.checkKeyword(1, 5, "eturn", .RETURN),
            's' => return self.checkKeyword(1, 4, "uper", .SUPER),
            't' => {
                if (self.current - self.start > 1) {
                    switch (self.start[1]) {
                        'h' => return self.checkKeyword(2, 2, "is", .THIS),
                        'r' => return self.checkKeyword(2, 2, "ue", .TRUE),
                        else => return .IDENTIFIER,
                    }
                } else {
                    return .IDENTIFIER;
                }
            },
            'v' => return self.checkKeyword(1, 2, "ar", .VAR),
            'w' => return self.checkKeyword(1, 4, "hile", .WHILE),
            else => return .IDENTIFIER,
        }
    }

    fn checkKeyword(self: *Self, start: usize, length: usize, rest: []const u8, ttype: TokenType) TokenType {
        if (self.current - self.start == start + length and std.mem.eql(u8, self.start[start .. start + length], rest)) {
            return ttype;
        }

        return .IDENTIFIER;
    }
};
