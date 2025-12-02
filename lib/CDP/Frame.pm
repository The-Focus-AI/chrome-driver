package CDP::Frame;
use strict;
use warnings;
use MIME::Base64 ();

# RFC 6455 WebSocket Frame Implementation
# Frame format:
#  0                   1                   2                   3
#  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
# +-+-+-+-+-------+-+-------------+-------------------------------+
# |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
# |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
# |N|V|V|V|       |S|             |   (if payload len==126/127)   |
# | |1|2|3|       |K|             |                               |
# +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +

use constant {
    OPCODE_CONTINUATION => 0x00,
    OPCODE_TEXT         => 0x01,
    OPCODE_BINARY       => 0x02,
    OPCODE_CLOSE        => 0x08,
    OPCODE_PING         => 0x09,
    OPCODE_PONG         => 0x0A,
};

sub new {
    my ($class, %opts) = @_;
    return bless {
        buffer => '',
        %opts,
    }, $class;
}

# Encode a frame for sending (client->server requires masking)
sub encode {
    my ($self, $payload, %opts) = @_;

    my $opcode = $opts{opcode} // OPCODE_TEXT;
    my $fin    = $opts{fin}    // 1;
    my $mask   = $opts{mask}   // 1;  # Clients must mask

    $payload //= '';
    my $len = length($payload);

    # First byte: FIN + opcode
    my $frame = chr(($fin ? 0x80 : 0x00) | $opcode);

    # Second byte: MASK + payload length
    my $mask_bit = $mask ? 0x80 : 0x00;

    if ($len < 126) {
        $frame .= chr($mask_bit | $len);
    }
    elsif ($len < 65536) {
        $frame .= chr($mask_bit | 126);
        $frame .= pack('n', $len);
    }
    else {
        $frame .= chr($mask_bit | 127);
        $frame .= pack('Q>', $len);
    }

    # Masking key and masked payload (required for client->server)
    if ($mask) {
        my $mask_key = pack('N', int(rand(0xFFFFFFFF)));
        $frame .= $mask_key;
        $frame .= $self->_apply_mask($payload, $mask_key);
    }
    else {
        $frame .= $payload;
    }

    return $frame;
}

# Decode a frame from received data
# Returns: { opcode, payload, fin, complete } or undef if incomplete
sub decode {
    my ($self, $data) = @_;

    $self->{buffer} .= $data if defined $data;

    my $buf = $self->{buffer};
    my $len = length($buf);

    # Need at least 2 bytes for header
    return undef if $len < 2;

    my $b1 = ord(substr($buf, 0, 1));
    my $b2 = ord(substr($buf, 1, 1));

    my $fin    = ($b1 & 0x80) ? 1 : 0;
    my $opcode = $b1 & 0x0F;
    my $masked = ($b2 & 0x80) ? 1 : 0;
    my $payload_len = $b2 & 0x7F;

    my $header_len = 2;

    # Extended payload length
    if ($payload_len == 126) {
        return undef if $len < 4;
        $payload_len = unpack('n', substr($buf, 2, 2));
        $header_len = 4;
    }
    elsif ($payload_len == 127) {
        return undef if $len < 10;
        $payload_len = unpack('Q>', substr($buf, 2, 8));
        $header_len = 10;
    }

    # Masking key (if present)
    my $mask_key;
    if ($masked) {
        return undef if $len < $header_len + 4;
        $mask_key = substr($buf, $header_len, 4);
        $header_len += 4;
    }

    # Full frame needed
    my $total_len = $header_len + $payload_len;
    return undef if $len < $total_len;

    # Extract payload
    my $payload = substr($buf, $header_len, $payload_len);

    # Unmask if needed
    if ($masked) {
        $payload = $self->_apply_mask($payload, $mask_key);
    }

    # Remove processed frame from buffer
    $self->{buffer} = substr($buf, $total_len);

    return {
        fin     => $fin,
        opcode  => $opcode,
        payload => $payload,
        complete => 1,
    };
}

# Create a text frame
sub text_frame {
    my ($self, $text) = @_;
    return $self->encode($text, opcode => OPCODE_TEXT);
}

# Create a close frame
sub close_frame {
    my ($self, $code, $reason) = @_;
    my $payload = '';
    if (defined $code) {
        $payload = pack('n', $code);
        $payload .= $reason if defined $reason;
    }
    return $self->encode($payload, opcode => OPCODE_CLOSE);
}

# Create a ping frame
sub ping_frame {
    my ($self, $data) = @_;
    return $self->encode($data // '', opcode => OPCODE_PING);
}

# Create a pong frame
sub pong_frame {
    my ($self, $data) = @_;
    return $self->encode($data // '', opcode => OPCODE_PONG);
}

# Apply XOR mask to data
sub _apply_mask {
    my ($self, $data, $mask_key) = @_;
    my @mask = unpack('C4', $mask_key);
    my $result = '';
    my $i = 0;
    for my $byte (unpack('C*', $data)) {
        $result .= chr($byte ^ $mask[$i % 4]);
        $i++;
    }
    return $result;
}

# Check if opcode is a control frame
sub is_control {
    my ($self, $opcode) = @_;
    return ($opcode & 0x08) ? 1 : 0;
}

# Get remaining buffer
sub buffer {
    my $self = shift;
    return $self->{buffer};
}

# Clear buffer
sub clear_buffer {
    my $self = shift;
    $self->{buffer} = '';
}

1;
