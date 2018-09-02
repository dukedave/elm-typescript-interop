module TypeScript.Generator exposing (elmModuleNamespace, generate, generatePort, generatePorts, prefix, wrapPorts)

import Result.Extra
import String.Interpolate
import TypeScript.Data.Aliases exposing (Aliases)
import TypeScript.Data.Port as Port
import TypeScript.Data.Program as Program exposing (Main)
import TypeScript.TypeGenerator exposing (toTsType)


generatePort : Aliases -> Port.Port -> Result String String
generatePort aliases (Port.Port name direction portType) =
    (case direction of
        Port.Outbound ->
            toTsType aliases portType
                |> Result.map
                    (\tsType -> "subscribe(callback: (data: " ++ tsType ++ ") => void)")

        Port.Inbound ->
            toTsType aliases portType
                |> Result.map (\tsType -> "send(data: " ++ tsType ++ ")")
    )
        |> Result.map
            (\inner ->
                String.Interpolate.interpolate
                    """    {0}: {
      {1}: void
    }"""
                    [ name, inner ]
            )


prefix : String
prefix =
    """// WARNING: Do not manually modify this file. It was generated using:
// https://github.com/dillonkearns/elm-typescript-interop
// Type definitions for Elm ports
export as namespace Elm"""


elmModuleNamespace : Aliases -> Main -> Result String String
elmModuleNamespace aliases main =
    let
        fullscreenParamResult =
            case main.flagsType of
                Nothing ->
                    Ok ""

                Just flagsType ->
                    toTsType aliases flagsType
                        |> Result.map
                            (\flagsTsType -> "flags: " ++ flagsTsType)

        moduleName =
            String.join "." main.moduleName

        embedAppendParamResult =
            case main.flagsType of
                Nothing ->
                    Ok ""

                Just flagsType ->
                    toTsType aliases flagsType
                        |> Result.map (\tsFlagsType -> ", flags: " ++ tsFlagsType)
    in
    case ( embedAppendParamResult, fullscreenParamResult ) of
        ( Ok embedAppendParam, Ok fullscreenParam ) ->
            "export namespace "
                ++ moduleName
                ++ """ {
  export function fullscreen("""
                ++ fullscreenParam
                ++ """): App
  export function embed(node: HTMLElement | null"""
                ++ embedAppendParam
                ++ """): App
}"""
                |> Ok

        ( result1, result2 ) ->
            Result.Extra.combine [ result1, result2 ]
                |> Result.map (\_ -> "")


generatePorts : Aliases -> List Port.Port -> Result String String
generatePorts aliases ports =
    ports
        |> List.map (generatePort aliases)
        |> Result.Extra.combine
        |> Result.map (String.join "\n")
        |> Result.map wrapPorts


wrapPorts : String -> String
wrapPorts portsString =
    """
export interface App {
  ports: {
"""
        ++ portsString
        ++ """
  }
}
    """


generate : Program.Program -> Result String String
generate program =
    case program of
        Program.ElmProgram main aliases ports ->
            case
                [ Ok prefix
                , generatePorts aliases ports
                , elmModuleNamespace aliases main
                ]
                    |> Result.Extra.combine
            of
                Ok list ->
                    list
                        |> String.join "\n\n"
                        |> Ok

                Err errorMessage ->
                    Err errorMessage
