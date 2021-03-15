// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import {HashFunction as hf} from "./SafeHash.sol";
// import {GuessTheMagicWord as g} from "./compraHash.sol";

/// @title Contrato de compra e venda de imóveis
/// @author Alexandre T. de Oliveira
/// @notice Essa implementação pode ser adaptada para outros tipos de contratos de venda.
/// @notice Transações realizadas à vista somente.
contract Venda_imovel {
    
  // DECLARAÇÃO DE VARIÁVEIS
    
  // enum Forma_pagamento { A_vista, Parcelado }
  enum Estado { Vazio, Ativo, Em_andamento, Liberado }        // Define o estado do anúncio
    
  struct anuncio {
    address payable vendedor;
    address payable comprador;
    uint valorImovel;    // Em Wei. 
    bytes32 safeHash;
    Estado estado;       // Como padrão, a variável recebe o seu primeiro membro (Estado.Vazio)
    // uint prazoEntrega;
    // Forma_pagamento public forma;
  }
    
  mapping(uint => anuncio) public Anuncios;      // Dicionário que mapeia os anúncios vinculados a esse Smart Contract
  uint[] listAnuncios;
  uint numAnuncios;                       // Identificador para selecionar algum anúncio


  // DECLARAÇÃO DE EVENTOS
  // Def.: São abstrações em alto nível da funcionalidade de log (registro histórico) da EVM (Ethereum Virtual Machine)
  // Aplicações podem registrar e escutar esses eventos através da interface RPC de um cliente Ethereum.

  event NovoAnuncio(address vendedor, uint _valorImovel, uint _idAnuncio);
  event Abortado(address vendedor, uint _idAnuncio);
  event CompraConfirmada(address comprador, uint _idAnuncio);
  event ItemRecebido(uint _idAnuncio);
  event CompradorReembolsado(uint _idAnuncio, address comprador);
  event AnunciosAtivos(uint[]);
    
    
  // DECLARAÇÃO DE FUNÇÕES
    
  /// @dev Inicializa um anúncio de venda de algum imóvel, guardando no mapping Anuncios.
  /// @param _valorImovel Valor do imóvel a ser anunciado.
  /// @return anuncioID Identificador do anúncio no mapping Anuncios.
  function anunciar(uint _valorImovel) public returns (uint anuncioID){
    listAnuncios.push(numAnuncios);
		anuncioID = numAnuncios++;
		emit NovoAnuncio(msg.sender, _valorImovel, anuncioID);
		Anuncios[anuncioID].valorImovel= _valorImovel;
		Anuncios[anuncioID].vendedor = payable(msg.sender);
		Anuncios[anuncioID].estado = Estado.Ativo;
	}
    

  /// @dev Aborta o anúncio do imóvel.
  /// @notice Deve ser chamada pelo vendedor e o anúncio deve estar ativo.
  /// @param id Identificador do anúncio a ser abortado.
  function abortar(uint id) public {
    anuncio storage a = Anuncios[id];
    require(msg.sender == a.vendedor,"Somente o vendedor pode chamar esta funcao!");
    require(a.estado == Estado.Ativo, "Estado invalido.");
    
    emit Abortado(msg.sender, id);
    limparAnuncio(id);
  }

  /// @dev Devolve uma lista de identificadores de anúncios.
  /// @notice Devido a dificuldades no acesso ao valor de retorno da função, o valor será passado através de um event.
  function listarAnuncios() public {
    emit AnunciosAtivos(listAnuncios); 
  }

  /// @dev Confirma a compra da parte do comprador.
  /// @notice Deve ser passado um "senha" para garantir que o valor seja repassado somente ao final da transação.
  /// @notice O Ether será bloqueado até a função "confirmarRecebimento" for chamada.
  /// @param id Identificador do anúncio vinculado à compra do imóvel.
  /// @param _safeHash Senha definida pelo comprador para "travar" o dinheiro no saldo do contrato.
  function comprar(uint id, string memory _safeHash) public payable {
    anuncio storage a = Anuncios[id];
    require(a.vendedor != address(0), "Anuncio inexistente.");
    require(a.estado == Estado.Ativo, "Estado invalido.");
    require(msg.value == a.valorImovel, "Quantia paga invalida, confirme o valor da compra.");
        
    emit CompraConfirmada(msg.sender, id);
    a.estado = Estado.Em_andamento;
        
    a.comprador = payable(msg.sender);
    a.safeHash = hf.hash(_safeHash, id, msg.sender);
  }

    
  /// @dev Confirma que o comprador recebeu seu item (documentação do imóvel).
  /// @notice Essa função vai liberar o Ether, através da "senha" definida pelo comprador.
  /// @notice Tanto o comprador quanto o vendedor podem chamar essa função com a senha.
  /// @param id Identificador do anúncio a ser confirmado a entrega.
  /// @param key "Senha" de segurança definida pelo comprador para destravar o valor da compra.
  function confirmarRecebimento(uint id, string memory key) public {
    anuncio storage a = Anuncios[id];
    require(a.estado == Estado.Em_andamento, "Estado invalido.");
    require(msg.sender == a.vendedor || msg.sender == a.comprador, "Somente o vendedor ou o comprador podem chamar essa funcao!");
        
    if (hf.hash(key, id, a.comprador) == a.safeHash) {
      emit ItemRecebido(id);
      a.estado = Estado.Liberado;

      a.vendedor.transfer(a.valorImovel);
      limparAnuncio(id);    
    }
  }


  /// @dev Reembolsa o comprador. Devolve ao comprador o Ether bloqueado referente à compra do imóvel.
  /// @param id Identificador do anúncio vinculado à compra.
  /// @param key "Senha" de segurança definida pelo comprador para destravar o valor da compra.
  function pedirReembolso(uint id, string memory key) public {
    anuncio storage a = Anuncios[id];
    require(a.comprador == msg.sender, "Somente o comprador pode chamar esta funcao!");
    require(a.estado == Estado.Em_andamento, "Estado invalido.");
        
    if (hf.hash(key, id, a.comprador) == a.safeHash) {
      emit CompradorReembolsado(id, msg.sender);
      a.estado = Estado.Ativo;

      a.comprador.transfer(a.valorImovel);
      a.comprador = payable(address(0));
    }
  }
    
  /// @dev Limpa o espaço onde está salvo o anúncio.
  /// @param id Identificador do anúncio a ser limpo.
  function limparAnuncio(uint id) private {
    remove(id);
    anuncio storage a = Anuncios[id];
	    
    a.comprador = payable(address(0));
	  a.vendedor = payable(address(0));
	  a.valorImovel = 0;
	  a.safeHash = 0;
	  a.estado = Estado.Vazio;
	}
    
  /// @dev Remove um identificador da listAnuncios.
  /// @param id Identificador do anúncio a ser removido da lista.
  function remove(uint id) private {
    for (uint i = 0; i < listAnuncios.length-1; i++){
      if(listAnuncios[i] >= id)
        listAnuncios[i] = listAnuncios[i+1];
    }
    delete listAnuncios[listAnuncios.length-1];
    listAnuncios.pop();
  }
}
