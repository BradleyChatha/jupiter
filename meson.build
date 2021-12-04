project('jupiter', 'd')

tool_x86_64_src = [
    'tools/x86_64.d',
    'source/jupiter/x86_64/info.d'
]

tool_x86_64_exe = executable(
    'x86_64_gen',
    tool_x86_64_src,
    include_directories: include_directories('source/'),
    d_args: ['-J../views']
)