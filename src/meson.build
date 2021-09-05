conf = configuration_data()
conf.set('prefix', get_option('prefix'))
conf.set('libdir', get_option ('libdir'))
conf.set('PROJECT_NAME', 'com.github.tudo75.xed-sessionsaver-plugin')
conf.set('PROJECT_VERSION', meson.project_version())

pluginsdatadir = join_paths(datadir, 'xed', 'plugins')
pluginslibdir = join_paths(libdir, 'xed', 'plugins')

sources = files(
    'sessionsaver.vala',
    'session.vala',
    'dialogs.vala',
)

sources += gnome.compile_resources(
    meson.project_name() + '.resources',
    '../data/com.github.tudo75.xed-sessionsaver-plugin.gresource.xml',
    source_dir: '../data',
)

libsessionsaver = library(
    'sessionsaver',
    sources,
    vala_header: 'sessionsaver.h',
    dependencies : dependencies,
    vala_args: [
        '--abi-stability'
    ],
    install: true,
    include_directories: include_dirs,
    install_rpath: join_paths(prefix, libdir, 'xed'),
    install_dir: [
        pluginslibdir,
        true,
        vapidir,
    ]
)

# install_data(
#     'ui/sessionsaver.ui',
#     install_dir: join_paths(
#         pluginsdatadir,
#         'sessionsaver',
#     )
# )