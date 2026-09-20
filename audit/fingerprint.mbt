///|
fn rotate_right(value : UInt, count : Int) -> UInt {
  (value >> count) | (value << (32 - count))
}

///|
fn sha256_constants() -> FixedArray[UInt] {
  [
    0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU, 0x59f111f1U,
    0x923f82a4U, 0xab1c5ed5U, 0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U,
    0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U, 0xc19bf174U, 0xe49b69c1U, 0xefbe4786U,
    0x0fc19dc6U, 0x240ca1ccU, 0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU,
    0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U, 0xc6e00bf3U, 0xd5a79147U,
    0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU, 0x53380d13U,
    0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U, 0xa2bfe8a1U, 0xa81a664bU,
    0xc24b8b70U, 0xc76c51a3U, 0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U,
    0x19a4c116U, 0x1e376c08U, 0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU,
    0x5b9cca4fU, 0x682e6ff3U, 0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
    0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U,
  ]
}

///|
fn padded_message(text : String) -> Array[Byte] {
  let message = @utf8.encode(text).to_array()
  let original_length = message.length()
  message.push(b'\x80')
  while message.length() % 64 != 56 {
    message.push(b'\x00')
  }
  let bit_length = original_length.to_uint64() * 8UL
  for index in 0..<8 {
    let shift = (7 - index) * 8
    message.push(((bit_length >> shift).to_uint() & 0xffU).to_byte())
  }
  message
}

///|
fn sha256_words(text : String) -> FixedArray[UInt] {
  let constants = sha256_constants()
  let message = padded_message(text)
  let mut h0 = 0x6a09e667U
  let mut h1 = 0xbb67ae85U
  let mut h2 = 0x3c6ef372U
  let mut h3 = 0xa54ff53aU
  let mut h4 = 0x510e527fU
  let mut h5 = 0x9b05688cU
  let mut h6 = 0x1f83d9abU
  let mut h7 = 0x5be0cd19U
  for chunk_start = 0
      chunk_start < message.length()
      chunk_start = chunk_start + 64 {
    let words = FixedArray::make(64, 0U)
    for index in 0..<16 {
      let offset = chunk_start + index * 4
      words[index] = (message[offset].to_uint() << 24) |
        (message[offset + 1].to_uint() << 16) |
        (message[offset + 2].to_uint() << 8) |
        message[offset + 3].to_uint()
    }
    for index in 16..<64 {
      let previous = words[index - 15]
      let s0 = rotate_right(previous, 7) ^
        rotate_right(previous, 18) ^
        (previous >> 3)
      let earlier = words[index - 2]
      let s1 = rotate_right(earlier, 17) ^
        rotate_right(earlier, 19) ^
        (earlier >> 10)
      words[index] = words[index - 16] + s0 + words[index - 7] + s1
    }
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    let mut f = h5
    let mut g = h6
    let mut h = h7
    for index in 0..<64 {
      let sum1 = rotate_right(e, 6) ^ rotate_right(e, 11) ^ rotate_right(e, 25)
      let choose = (e & f) ^ (e.lnot() & g)
      let temporary1 = h + sum1 + choose + constants[index] + words[index]
      let sum0 = rotate_right(a, 2) ^ rotate_right(a, 13) ^ rotate_right(a, 22)
      let majority = (a & b) ^ (a & c) ^ (b & c)
      let temporary2 = sum0 + majority
      h = g
      g = f
      f = e
      e = d + temporary1
      d = c
      c = b
      b = a
      a = temporary1 + temporary2
    }
    h0 += a
    h1 += b
    h2 += c
    h3 += d
    h4 += e
    h5 += f
    h6 += g
    h7 += h
  }
  [h0, h1, h2, h3, h4, h5, h6, h7]
}

///|
fn write_hex_word(output : StringBuilder, value : UInt) -> Unit {
  let encoded = value.to_string(radix=16)
  for _ in encoded.length()..<8 {
    output.write_char('0')
  }
  output.write_string(encoded)
}

///|
/// Return a stable SHA-256 fingerprint of the exact UTF-8 context bytes.
///
/// The result includes the algorithm prefix so reports remain unambiguous if
/// additional fingerprint algorithms are introduced later.
///
/// ```mbt check
/// test {
///   inspect(
///     @audit.fingerprint("abc"),
///     content="sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
///   )
/// }
/// ```
pub fn fingerprint(text : String) -> String {
  let output = StringBuilder()
  output.write_string("sha256:")
  for word in sha256_words(text) {
    write_hex_word(output, word)
  }
  output.to_string()
}
