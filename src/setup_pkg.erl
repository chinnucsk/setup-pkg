
%%% -*- mode: erlang -*-

%%%----------------------------------------------------------------------
%%% File     : setup_pkg.erl
%%% Purpose  : Setup Package escript
%%%----------------------------------------------------------------------

-module(setup_pkg).

-export([main/1]).

-ifndef(PKG).
-define(PKG, "pkg").
-endif.

-ifndef(VSN).
-define(VSN, "HEAD").
-endif.

%%%===================================================================
%%% API
%%%===================================================================

main([]) ->
	getopt:usage(option_spec_list(), escript:script_name());
main(Args) ->
    try
        OptSpecList = option_spec_list(),
        case getopt:parse(OptSpecList, Args) of
            {ok, {Options, _NonOptArgs}} ->
                Pkg = proplists:get_value(pkg,Options,pkg()),
                Vsn = proplists:get_value(vsn,Options,vsn()),
                Conf = proplists:get_value(conf,Options,conf(Pkg)),
                Dir = proplists:get_value(dir,Options,dir()),

                Install = proplists:get_value(install,Options,false),
                [ begin
                      io:format("Installing ~p (~p) ... ~n", [Pkg, Vsn]),

                      LibDir = filename:join([Dir, "lib", Vsn]),
                      RelDir = filename:join([Dir, "releases", Vsn]),

                      ok = filelib:ensure_dir(filename:join(LibDir, "dummy")),
                      ok = filelib:ensure_dir(filename:join(RelDir, "dummy")),

                      ZipEz = filename:join(LibDir, Pkg ++ "-" ++ Vsn ++ ".ez"),
                      {ok, [_, _, _, {archive, Zip}]} = escript:extract(escript:script_name(), []),
                      ok = file:write_file(ZipEz, Zip),

                      {ok, ZipEzFileInfo} = file:read_file_info(ZipEz),
                      try
                          ok = code:set_primary_archive(ZipEz, Zip, ZipEzFileInfo, fun escript:parse_file/1)
                      catch
                          error:undef ->
                              ok = code:set_primary_archive(ZipEz, Zip, ZipEzFileInfo)
                      end,

                      ok = setup_gen:run([{name, "rel"}
                                          , {vsn, Vsn}
                                          , {conf, Conf}
                                          , {outdir, RelDir}
                                          , {install, true}
                                         ])
                  end || Install ];
            {error, {Reason, Data}} ->
                io:format("Error: ~s ~p~n~n", [Reason, Data]),
                getopt:usage(OptSpecList, escript:script_name())
        end
    after
        timer:sleep(100)
    end.

%%%===================================================================
%%% Internal functions
%%%===================================================================

option_spec_list() ->
	[
     {pkg,     $p, "package",   {string,pkg()},  "Package                (string: \"" ++ pkg()    ++ "\")"},
     {vsn,     $v, "vsn",       {string,vsn()},  "Version                (string: \"" ++ vsn()    ++ "\")"},
     {conf,    $c, "config",    {string,conf()}, "Configuration File     (filename: \"" ++ conf() ++ "\")"},
     {dir,     $d, "directory", {string,dir()},  "Installation Directory (dirname: \"" ++ dir()   ++ "\")"},
     {install, $i, "install",   {boolean,false}, "Install                (boolean: 'false')"}
    ].

pkg() ->
    ?PKG.

vsn() ->
    ?VSN.

conf() ->
    conf(pkg()).

conf(Pkg) ->
    Pkg ++ ".conf".

dir() ->
    "./".
