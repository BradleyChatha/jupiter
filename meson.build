project('jupiter', 'd')

tool_x86_64_src = [
    'tools/x86_64.d',
]

executable(
    'x86_64_info',
    tool_x86_64_src,
    include_directories: include_directories('source/'),
    d_args: ['-J../views'],
    d_module_versions: ['Info']
)

executable(
    'x86_64_ir',
    'source/jupiter/x86_64/info.d',
    tool_x86_64_src,
    include_directories: include_directories('source/'),
    d_args: ['-J../views'],
    d_module_versions: ['Ir']
)