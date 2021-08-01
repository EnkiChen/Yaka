#import "Shader.h"

#include <algorithm>
#include <array>
#include <memory>

// Vertex shader doesn't do anything except pass coordinates through.
const char kVertexShaderSource[] =
SHADER_VERSION
VERTEX_SHADER_IN " vec2 position;\n"
VERTEX_SHADER_IN " vec2 texcoord;\n"
VERTEX_SHADER_OUT " vec2 v_texcoord;\n"
"void main() {\n"
"    gl_Position = vec4(position.x, position.y, 0.0, 1.0);\n"
"    v_texcoord = texcoord;\n"
"}\n";

// Compiles a shader of the given |type| with GLSL source |source| and returns
// the shader handle or 0 on error.
GLuint CreateShader(GLenum type, const GLchar *source) {
    GLuint shader = glCreateShader(type);
    if (!shader) {
        return 0;
    }
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    GLint compileStatus = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileStatus);
    if (compileStatus == GL_FALSE) {
        GLint logLength = 0;
        // The null termination character is included in the returned log length.
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            std::unique_ptr<char[]> compileLog(new char[logLength]);
            // The returned string is null terminated.
            glGetShaderInfoLog(shader, logLength, NULL, compileLog.get());
        }
        glDeleteShader(shader);
        shader = 0;
    }
    return shader;
}

// Links a shader program with the given vertex and fragment shaders and
// returns the program handle or 0 on error.
GLuint CreateProgram(GLuint vertexShader, GLuint fragmentShader) {
    if (vertexShader == 0 || fragmentShader == 0) {
        return 0;
    }
    GLuint program = glCreateProgram();
    if (!program) {
        return 0;
    }
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);
    GLint linkStatus = GL_FALSE;
    glGetProgramiv(program, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == GL_FALSE) {
        glDeleteProgram(program);
        program = 0;
    }
    return program;
}

// Creates and links a shader program with the given fragment shader source and
// a plain vertex shader. Returns the program handle or 0 on error.
GLuint CreateProgramFromFragmentSource(const char fragmentShaderSource[]) {
    GLuint vertexShader = CreateShader(GL_VERTEX_SHADER, kVertexShaderSource);
    GLuint fragmentShader =
    CreateShader(GL_FRAGMENT_SHADER, fragmentShaderSource);
    GLuint program = CreateProgram(vertexShader, fragmentShader);
    // Shaders are created only to generate program.
    if (vertexShader) {
        glDeleteShader(vertexShader);
    }
    if (fragmentShader) {
        glDeleteShader(fragmentShader);
    }
    
    // Set vertex shader variables 'position' and 'texcoord' in program.
    GLint position = glGetAttribLocation(program, "position");
    GLint texcoord = glGetAttribLocation(program, "texcoord");
    if (position < 0 || texcoord < 0) {
        glDeleteProgram(program);
        return 0;
    }
    
    // Read position attribute with size of 2 and stride of 4 beginning at the start of the array. The
    // last argument indicates offset of data within the vertex buffer.
    glVertexAttribPointer(position, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (void *)0);
    glEnableVertexAttribArray(position);
    
    // Read texcoord attribute  with size of 2 and stride of 4 beginning at the first texcoord in the
    // array. The last argument indicates offset of data within the vertex buffer.
    glVertexAttribPointer(
                          texcoord, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (void *)(2 * sizeof(GLfloat)));
    glEnableVertexAttribArray(texcoord);
    
    return program;
}

bool CreateVertexBuffer(GLuint *vertexBuffer, GLuint *vertexArray) {
#if !TARGET_OS_IPHONE
    glGenVertexArrays(1, vertexArray);
    if (*vertexArray == 0) {
        return NO;
    }
    glBindVertexArray(*vertexArray);
#endif
    glGenBuffers(1, vertexBuffer);
    if (*vertexBuffer == 0) {
        glDeleteVertexArrays(1, vertexArray);
        return NO;
    }
    glBindBuffer(GL_ARRAY_BUFFER, *vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, 4 * 4 * sizeof(GLfloat), NULL, GL_DYNAMIC_DRAW);
    return YES;
}

// Set vertex data to the currently bound vertex buffer.
void SetVertexData(VideoRotation rotation, bool enableMirror) {
    // When modelview and projection matrices are identity (default) the world is
    // contained in the square around origin with unit size 2. Drawing to these
    // coordinates is equivalent to drawing to the entire screen. The texture is
    // stretched over that square using texture coordinates (u, v) that range
    // from (0, 0) to (1, 1) inclusive. Texture coordinates are flipped vertically
    // here because the incoming frame has origin in upper left hand corner but
    // OpenGL expects origin in bottom left corner.
    std::array<std::array<GLfloat, 2>, 4> UVCoords = {{
        {{0, 1}},  // Lower left.
        {{1, 1}},  // Lower right.
        {{1, 0}},  // Upper right.
        {{0, 0}},  // Upper left.
    }};
    
    // Rotate the UV coordinates.
    int rotation_offset;
    switch (rotation) {
        case VideoRotation_0:
            rotation_offset = 0;
            break;
        case VideoRotation_90:
            rotation_offset = 1;
            break;
        case VideoRotation_180:
            rotation_offset = 2;
            break;
        case VideoRotation_270:
            rotation_offset = 3;
            break;
    }
    std::rotate(UVCoords.begin(), UVCoords.begin() + rotation_offset,
                UVCoords.end());
    
    const GLfloat gVertices[] = {
        // X, Y, U, V.
        -1, -1, UVCoords[0][0], UVCoords[0][1],
        1, -1, UVCoords[1][0], UVCoords[1][1],
        1,  1, UVCoords[2][0], UVCoords[2][1],
        -1,  1, UVCoords[3][0], UVCoords[3][1],
    };
    
    const GLfloat mVertices[] = {
        // X, Y, U, V.
        1, -1, UVCoords[0][0], UVCoords[0][1],
        -1, -1, UVCoords[1][0], UVCoords[1][1],
        -1,  1, UVCoords[2][0], UVCoords[2][1],
        1,  1, UVCoords[3][0], UVCoords[3][1],
    };
    
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(gVertices), enableMirror ? mVertices : gVertices);
}

