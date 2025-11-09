import qualified Data.Map.Strict as Map
import Data.Time (UTCTime, getCurrentTime)
import Control.Exception (catch, SomeException, fromException, evaluate)
import System.IO (IOMode(..), openFile, hClose, hGetContents, readFile, writeFile, appendFile)
import System.IO.Error (isDoesNotExistError)
import Data.List (sortBy, groupBy, sortOn, isInfixOf)
import Data.Ord (Down(..), comparing)
import Data.Maybe (mapMaybe)


data Item = Item {

    itemID :: String,
    
    nome :: String,
    
    quantidade :: Int,
    
    categoria :: String
    
} deriving (Show, Read)


type Inventario = Map.Map String Item


data AcaoLog = Add | Remove | UpdateQty | QueryFail | Report
    deriving (Show, Read, Eq)


data StatusLog = Sucesso | Falha String
    deriving (Show, Read, Eq)


data LogEntry = LogEntry {

    timestamp :: UTCTime,
    
    acao :: AcaoLog,
    
    detalhes :: String,
    
    status :: StatusLog
    
} deriving (Show, Read)


type ResultadoOperacao = (Inventario, LogEntry)


addItem :: UTCTime -> String -> String -> Int -> String -> Inventario -> Either String ResultadoOperacao
addItem agora id nome qtde cat inv =

    if Map.member id inv
    
        then Left "❌ERRO AO ADICIONAR UM ITEM: Já existe um item com esse id no inventário. :("
        
        else

            let novoItem = Item { itemID = id, nome = nome, quantidade = qtde, categoria = cat }

                novoInv = Map.insert id novoItem inv

                detalhesOp = "ID =" ++ id ++ " Nome =" ++ nome ++ " Quantidade =" ++ show qtde ++ " Categoria =" ++ cat
                
                logEntry = LogEntry {
                
                    timestamp = agora,
                    acao = Add,
                    detalhes = detalhesOp,
                    status = Sucesso
                    
                }

            in Right (novoInv, logEntry)


atualizarEstoque :: UTCTime -> String -> Int -> Inventario -> Either String ResultadoOperacao
atualizarEstoque agora id qtdeMudar inv =

    case Map.lookup id inv of
    
        Nothing -> Left "❌ERRO AO ATUALIZAR ESTOQUE: Não existe item com esse ID no inventário. :("
        
        Just itemEncontrado ->
        
            let novaQtde = quantidade itemEncontrado + qtdeMudar
            
            in if novaQtde < 0
            
                then Left "❌ERRO AO ATUALIZAR ESTOQUE: Não há estoque suficiente para realizar essa movimentação. :(" 
                
                else
                
                    let itemAtualizado = itemEncontrado { quantidade = novaQtde }
                    
                        novoInv = Map.insert id itemAtualizado inv
                        
                        detalhesOp = "ID = " ++ id ++ " Quantidade movimentada = " ++ show qtdeMudar ++ " Novo total = " ++ show novaQtde
                        
                        logEntry = LogEntry {
                        
                            timestamp = agora,
                            
                            acao = if qtdeMudar > 0 then UpdateQty else Remove,
                            
                            detalhes = detalhesOp,
                            
                            status = Sucesso
                            
                        }
                        
                    in Right (novoInv, logEntry)


removeItem :: UTCTime -> String -> Int -> Inventario -> Either String ResultadoOperacao
removeItem agora id qtde inv =

    atualizarEstoque agora id (-qtde) inv


logsDeErro :: [LogEntry] -> [LogEntry]
logsDeErro logs = filter eDeErro logs
    where
      eDeErro (LogEntry _ _ _ (Falha _)) = True
      eDeErro _ = False 
      

historicoPorItem :: String -> [LogEntry] -> [LogEntry]
historicoPorItem id logs = filter (eDoItem id) logs
    where
      eDoItem id (LogEntry _ _ det _) = ("ID =" ++ id) `isInfixOf` det


itemMaisMovimentado :: [LogEntry] -> Maybe (String, Int)
itemMaisMovimentado logs =

    let todosIDs = mapMaybe extrairID logs

        gruposDeIDs = groupBy (==) (sortOn id todosIDs)

        contagens = map (\grupo -> (head grupo, length grupo)) gruposDeIDs

        contagensOrdenadas = sortOn (Down . snd) contagens

    in if null contagensOrdenadas
    
        then Nothing
        
        else Just (head contagensOrdenadas)
        
    where

        extrairID :: LogEntry -> Maybe String
        extrairID (LogEntry _ _ detalhes (Falha _)) = Nothing 
        extrairID (LogEntry _ QueryFail _ _) = Nothing       
        extrairID (LogEntry _ Report _ _) = Nothing         
        extrairID (LogEntry _ _ detalhes Sucesso) =
            let partes = words (map (\c -> if c == '=' then ' ' else c) detalhes)
            in case "ID" `elemIndex` partes of
                Just i -> if (i+1) < length partes then Just (partes !! (i+1)) else Nothing
                Nothing -> Nothing
        

        elemIndex :: Eq a => a -> [a] -> Maybe Int
        elemIndex _ [] = Nothing
        elemIndex x (y:ys)
            | x == y    = Just 0
            | otherwise = (1 +) <$> elemIndex x ys


inventarioFile = "Inventario.dat"
logFile = "Auditoria.log"

safeReadFile :: FilePath -> a -> (String -> a) -> IO a
safeReadFile path defaultVal parser =
    catch (do
        contents <- readFile path
        let parsed = parser contents
        
        evaluate parsed
        
    )

    (\(e :: SomeException) -> do

        case fromException e :: Maybe IOError of

            Just ioerr | isDoesNotExistError ioerr -> do
                putStrLn $ "Aviso: Arquivo '" ++ path ++ "' nao encontrado. Iniciando com dados padrao."
                return defaultVal

            _ -> do
                putStrLn $ "Aviso: Arquivo '" ++ path ++ "' corrompido ou ilegivel. Iniciando com dados padrao."
                return defaultVal
    )
    

loadState :: IO (Inventario, [LogEntry])
loadState = do
    putStrLn $ "Carregando " ++ inventarioFile ++ "..."
    
    inv <- safeReadFile inventarioFile Map.empty read
    putStrLn $ "Carregando " ++ logFile ++ "..."
    
    logs <- safeReadFile logFile [] (map read . lines)
    putStrLn "Estado carregado."
    return (inv, logs)


persistSucesso :: Inventario -> LogEntry -> IO ()
persistSucesso inv logEntry = do
    writeFile inventarioFile (show inv)
    appendFile logFile (show logEntry ++ "\n")


persistFalha :: LogEntry -> IO ()
persistFalha logEntry = do

    appendFile logFile (show logEntry ++ "\n")


main :: IO ()
main = do
    putStrLn "--- Sistema de Gerenciamento de Inventario (Haskell) ---"
    
    (inv, logs) <- loadState
    
    gameLoop inv logs
    putStrLn "--- Encerrando. ---"


gameLoop :: Inventario -> [LogEntry] -> IO ()
gameLoop inventario logs = do
    putStrLn "\nComandos:"
    putStrLn "  add <id> <nome> <qtde> <categoria>"
    putStrLn "  estoque <id> <qtde_mudar> (ex: 10 para adicionar, -5 para remover)"
    putStrLn "  remover <id> <qtde_remover> (ex: 5 para remover 5)"
    putStrLn "  listar"
    putStrLn "  relatorio erros"
    putStrLn "  relatorio item <id>"
    putStrLn "  relatorio mais_movimentado"
    putStrLn "  sair"
    putStr "Seu comando > "

    linha <- getLine
    let comando = words linha
    agora <- getCurrentTime

    case comando of
        ["add", id, nome, qtdeStr, cat] -> do
            let qtde = read qtdeStr :: Int
            let resultado = addItem agora id nome qtde cat inventario
            
            processarResultado agora comando resultado
            
        ["estoque", id, qtdeStr] -> do
            let qtde = read qtdeStr :: Int
            let resultado = atualizarEstoque agora id qtde inventario
            
            processarResultado agora comando resultado

        ["remover", id, qtdeStr] -> do
            let qtde = read qtdeStr :: Int
            let resultado = removeItem agora id qtde inventario
            
            processarResultado agora comando resultado

        ["listar"] -> do
            putStrLn "--- Inventario Atual ---"
            mapM_ print (Map.elems inventario)
            gameLoop inventario logs
            
        ["relatorio", "erros"] -> do
            putStrLn "--- Relatorio de Erros ---"
            mapM_ print (logsDeErro logs)
            gameLoop inventario logs

        ["relatorio", "item", id] -> do
            putStrLn $ "--- Historico do Item " ++ id ++ " ---"
            mapM_ print (historicoPorItem id logs)
            gameLoop inventario logs

        ["relatorio", "mais_movimentado"] -> do
            putStrLn $ "--- Item Mais Movimentado (Sucesso) ---"
            print (itemMaisMovimentado logs)
            gameLoop inventario logs

        ["sair"] -> do
            putStrLn "Salvando e saindo..."
            
        _ -> do
            putStrLn "Comando invalido ou numero incorreto de argumentos."
            let logFalha = LogEntry {
                timestamp = agora, 
                acao = QueryFail,
                detalhes = unwords comando, 
                status = Falha "Comando invalido"
            }
            persistFalha logFalha
            gameLoop inventario (logs ++ [logFalha])

    where

      processarResultado :: UTCTime -> [String] -> Either String ResultadoOperacao -> IO ()
      

      processarResultado agora comando (Left erroMsg) = do
          putStrLn $ "FALHA: " ++ erroMsg
          let logFalha = LogEntry {
                timestamp = agora, 
                acao = QueryFail, 
                detalhes = unwords comando, 
                status = Falha erroMsg
          }
          persistFalha logFalha
          gameLoop inventario (logs ++ [logFalha])

      processarResultado _ _ (Right (novoInv, logSucesso)) = do
          putStrLn "SUCESSO: Operacao registrada."
          persistSucesso novoInv logSucesso
          gameLoop novoInv (logs ++ [logSucesso])
