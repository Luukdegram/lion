usingnamespace @import("c.zig");

var initialized: bool = false;
var muted: bool = false;

//al related data that we save to cleanup later
var source: ALuint = undefined;
var context: *ALCcontext = undefined;

/// Initializes the audio system and opens the wave file.
/// Note that it's currently only possible to have 1 audio file active.
pub fn init(file_name: [*c]const u8, comptime buffer_size: comptime_int) !void {
    var device: *ALCdevice = undefined;

    var wave: drwav = undefined;
    if (drwav_init_file(&wave, file_name, null) == DRWAV_FALSE) {
        return error.FileRead;
    }

    // Caller defined buffer size
    var audio_buffer: [buffer_size]u8 = undefined;
    const actual_size = drwav_read_raw(&wave, buffer_size, &audio_buffer);

    defer _ = drwav_uninit(&wave);

    // Get default device
    if (alcOpenDevice("")) |dev| {
        device = dev;
    } else {
        return error.NoDevicesFound;
    }

    // Set the current context
    if (alcCreateContext(device, null)) |ctx| {
        context = ctx;
        if (alcMakeContextCurrent(context) == AL_FALSE) {
            return error.ContextFailed;
        }
    }

    // generate a source object and link to a new buffer we make
    var buffer: ALuint = undefined;
    alGenSources(1, &source);
    alGenBuffers(1, &buffer);
    alBufferData(buffer, AL_FORMAT_STEREO16, @ptrCast(*const c_void, &audio_buffer[0..actual_size]), @intCast(c_int, actual_size), @intCast(c_int, wave.sampleRate));
    alSourcei(source, AL_BUFFER, @intCast(c_int, buffer));

    initialized = true;

    // we already linked to our source, so cleanup this buffer
    alDeleteBuffers(1, &buffer);
}

/// Plays the audio file provided with the `init` function.
pub fn play() void {
    if (!initialized or muted) {
        return;
    }

    alSourcePlay(source);
}

/// Cleans the audio data and frees its memory
pub fn deinit() void {
    alDeleteSources(1, &source);
    const device = alcGetContextsDevice(context);
    _ = alcMakeContextCurrent(null);
    alcDestroyContext(context);
    _ = alcCloseDevice(device);
}

/// Muts or unmutes the audio
pub fn muteOrUnmute() void {
    muted = !muted;
}
