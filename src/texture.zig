usingnamespace @import("c.zig");
const Mutex = @import("std").Mutex;

const vertex_shader_source = @embedFile("shaders/vertex.glsl");
const fragment_shader_source = @embedFile("shaders/fragment.glsl");

/// Our texture quad
const vertices = &[_]GLfloat{
    1,  -1, 0.0, 1.0, 0.0, // bottom right
    1,  1,  0.0, 1.0, 1.0, // top right
    -1, -1, 0.0, 0.0, 0.0, // bottom left
    -1, 1,  0.0, 0.0, 1.0, // top left
};

/// Texture height
const height: c_int = 32;

/// Texture width
const width: c_int = 64;

/// Texture represents a quad texture that can be
/// used to render the display of our 8chip video memory
pub const Texture = struct {
    /// Vertex Array Object
    vao: GLuint,
    /// Vertex Buffer Object
    vbo: GLuint,
    /// Shader program
    shader_program: GLuint,
    /// texture id
    id: GLuint,
    /// texture pixel bytes in RGBA format
    /// The buffer is initialy filled by zeroes (making it transparant)
    buffer: [height * width * 4]u8 = [_]u8{255} ** width ** height ** 4,
    mutex: Mutex,

    /// Creates a new Texture using the given width and height
    pub fn init() !Texture {
        const fragment_id = try createShader(fragment_shader_source, GL_FRAGMENT_SHADER);
        const vertex_id = try createShader(vertex_shader_source, GL_VERTEX_SHADER);

        var program_id = glCreateProgram();
        glAttachShader(program_id, vertex_id);
        glAttachShader(program_id, fragment_id);
        glLinkProgram(program_id);

        var ok: c_int = undefined;
        glGetProgramiv(program_id, GL_LINK_STATUS, &ok);
        if (ok == GL_FALSE) {
            return error.ProgramLinkFailed;
        }
        glValidateProgram(program_id);

        glDeleteShader(vertex_id);
        glDeleteShader(fragment_id);

        var vao: GLuint = undefined;
        var vbo: GLuint = undefined;
        var tex_id: GLuint = undefined;
        glGenVertexArrays(1, &vao);
        glGenBuffers(1, &vbo);
        glGenTextures(1, &tex_id);
        glBindVertexArray(vao);

        // temporary empty buffer to load our gpu with a zeroes transparant texture
        var emptybuffer = [_]u8{0} ** width ** height ** 4;

        // create our texture
        glBindTexture(GL_TEXTURE_2D, tex_id);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(
            GL_TEXTURE_2D,
            0,
            GL_RGBA,
            width,
            height,
            0,
            GL_RGBA,
            GL_UNSIGNED_BYTE,
            @ptrCast(*c_void, &emptybuffer),
        );

        // our vertices buffer
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.len * @sizeOf(GLfloat), @ptrCast(*const c_void, vertices), GL_STATIC_DRAW);
        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * @sizeOf(GLfloat), null);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * @sizeOf(GLfloat), @intToPtr(*c_int, 3 * @sizeOf(GLfloat)));

        // unbind
        glBindVertexArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        return Texture{
            .vao = vao,
            .vbo = vbo,
            .shader_program = program_id,
            .id = tex_id,
            .mutex = Mutex.init(),
        };
    }

    /// Updates the texture based on the pixels of the given frame
    pub fn update(self: *Texture, frame: []u1) void {
        var lock = self.mutex.acquire();
        defer lock.release();

        // Perhaps write a more performant version of this
        var h = @intCast(usize, height);
        var i: usize = 0;
        var offset: usize = 0;
        var pixel: usize = 0;
        while (i < width) : (i += 1) {
            var j: usize = 0;
            while (j < height) : (j += 1) {
                self.buffer[offset + 3] = @intCast(u8, frame[pixel]) * 255;
                offset += 4;
                pixel += 1;
            }
        }
    }

    /// Renders the quad texture
    pub fn draw(self: *Texture) void {
        glUseProgram(self.shader_program);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, self.id);

        glTexSubImage2D(
            GL_TEXTURE_2D,
            0,
            0,
            0,
            width,
            height,
            GL_RGBA,
            GL_UNSIGNED_BYTE,
            @ptrCast(*c_void, &self.buffer),
        );

        glBindVertexArray(self.vao);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }

    /// Destroys the vao, vbo, shader program, and then itself
    pub fn deinit(self: *Texture) void {
        glDeleteVertexArrays(1, &self.vao);
        glDeleteBuffers(1, &self.vbo);
        glDeleteShader(self.shader_program);
        self.mutex.deinit();
        self.* = undefined;
    }
};

/// Creates a new shader source
fn createShader(source: []const u8, kind: GLenum) !GLuint {
    const id = glCreateShader(kind);
    const ptr: ?[*]const u8 = source.ptr;
    const len = @intCast(GLint, source.len);

    glShaderSource(id, 1, &ptr, null);
    glCompileShader(id);

    var ok: GLint = undefined;
    glGetShaderiv(id, GL_COMPILE_STATUS, &ok);
    if (ok != 0) return id;

    return error.ShaderCompilationFailed;
}
