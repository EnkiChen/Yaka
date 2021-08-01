#import "OpenGLDefines.h"
#import "VideoFrame.h"

extern "C" const char kVertexShaderSource[];

GLuint CreateShader(GLenum type, const GLchar *source);
GLuint CreateProgram(GLuint vertexShader, GLuint fragmentShader);
GLuint CreateProgramFromFragmentSource(const char fragmentShaderSource[]);
bool CreateVertexBuffer(GLuint* vertexBuffer, GLuint* vertexArray);
void SetVertexData(VideoRotation rotation, bool enableMirror);
