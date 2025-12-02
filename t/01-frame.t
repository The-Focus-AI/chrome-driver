#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib '../lib';
use lib 'lib';

use_ok('CDP::Frame');

my $frame = CDP::Frame->new();

# Test text frame encoding
{
    my $encoded = $frame->text_frame('Hello');
    ok(length($encoded) >= 7, 'Text frame has correct minimum length');

    # First byte: FIN=1, opcode=1 (text)
    my $b1 = ord(substr($encoded, 0, 1));
    is($b1 & 0x80, 0x80, 'FIN bit set');
    is($b1 & 0x0F, 0x01, 'Opcode is text');

    # Second byte: MASK=1, length=5
    my $b2 = ord(substr($encoded, 1, 1));
    is($b2 & 0x80, 0x80, 'Mask bit set');
    is($b2 & 0x7F, 5, 'Payload length is 5');
}

# Test close frame
{
    my $close = $frame->close_frame(1000, 'Normal');
    ok(length($close) >= 2, 'Close frame created');

    my $b1 = ord(substr($close, 0, 1));
    is($b1 & 0x0F, 0x08, 'Opcode is close');
}

# Test ping/pong frames
{
    my $ping = $frame->ping_frame('ping');
    my $b1 = ord(substr($ping, 0, 1));
    is($b1 & 0x0F, 0x09, 'Opcode is ping');

    my $pong = $frame->pong_frame('pong');
    $b1 = ord(substr($pong, 0, 1));
    is($b1 & 0x0F, 0x0A, 'Opcode is pong');
}

# Test frame decoding (unmasked server->client frame)
{
    my $decoder = CDP::Frame->new();

    # Build unmasked text frame: FIN=1, opcode=1, mask=0, len=5
    my $server_frame = chr(0x81) . chr(0x05) . 'Hello';

    my $decoded = $decoder->decode($server_frame);
    ok($decoded, 'Frame decoded');
    is($decoded->{opcode}, 1, 'Decoded opcode is text');
    is($decoded->{payload}, 'Hello', 'Decoded payload matches');
    is($decoded->{fin}, 1, 'FIN flag set');
}

# Test extended payload length (126-byte format)
{
    my $decoder = CDP::Frame->new();
    my $payload = 'x' x 200;

    # Build unmasked frame with extended length
    my $server_frame = chr(0x81) . chr(126) . pack('n', 200) . $payload;

    my $decoded = $decoder->decode($server_frame);
    ok($decoded, 'Extended length frame decoded');
    is(length($decoded->{payload}), 200, 'Payload length correct');
}

# Test incomplete frame handling
{
    my $decoder = CDP::Frame->new();

    # Only partial header
    my $result = $decoder->decode(chr(0x81));
    is($result, undef, 'Incomplete frame returns undef');

    # Complete the frame
    $result = $decoder->decode(chr(0x03) . 'abc');
    ok($result, 'Frame decoded after completion');
    is($result->{payload}, 'abc', 'Payload correct after reassembly');
}

# Test buffer management
{
    my $decoder = CDP::Frame->new();

    # Two frames in one buffer
    my $two_frames = chr(0x81) . chr(0x02) . 'AB' .
                     chr(0x81) . chr(0x02) . 'CD';

    my $first = $decoder->decode($two_frames);
    ok($first, 'First frame decoded');
    is($first->{payload}, 'AB', 'First payload correct');

    my $second = $decoder->decode(undef);
    ok($second, 'Second frame decoded from buffer');
    is($second->{payload}, 'CD', 'Second payload correct');
}

# Test control frame detection
{
    ok($frame->is_control(0x08), 'Close is control');
    ok($frame->is_control(0x09), 'Ping is control');
    ok($frame->is_control(0x0A), 'Pong is control');
    ok(!$frame->is_control(0x01), 'Text is not control');
    ok(!$frame->is_control(0x02), 'Binary is not control');
}

done_testing();
