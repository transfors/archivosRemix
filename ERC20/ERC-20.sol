// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleERC20Token {

    // name: Nombre del token.
    // symbol: Símbolo del token (como “ETH”, “DAI”).
    // decimals: Número de decimales 
    // (18 es el estándar en la mayoría de tokens ERC20).
    string public constant name = "SimpleERC20Token";
    string public constant symbol = "SET";
    uint8 public constant decimals = 18;

    // Los eventos permiten a las aplicaciones 
    // (como Metamask o Etherscan) seguir las transacciones y aprobaciones.
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // balances: Lleva el balance de cada dirección.
    // allowed: Maneja las aprobaciones entre usuarios 
    // (owner permite a spender gastar hasta cierta cantidad).
    // totalSupply_: Cantidad total de tokens en circulación.
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;
    uint256 totalSupply_;

    // Al desplegar el contrato, se define el totalSupply 
    // y todos los tokens se asignan al creador (msg.sender).
    constructor(uint256 total) {
        totalSupply_ = total;
        balances[msg.sender] = totalSupply_;
    }

    // Devuelve la cantidad total de tokens creados.
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    // Devuelve el balance de una cuenta.
    function balanceOf(address tokenOwner) public view returns (uint256) {
        return balances[tokenOwner];
    }

    // Permite que msg.sender le transfiera tokens 
    // directamente a otro usuario (receiver).
    function transfer(address receiver, uint256 numTokens) public returns (bool) {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender] - numTokens;
        balances[receiver] = balances[receiver] + numTokens;
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }

    // Autoriza a otro usuario (delegate) a gastar una cantidad 
    // de tokens en nombre del que llama la función (msg.sender).
    function approve(address delegate, uint256 numTokens) public returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    // Consulta cuántos tokens delegate puede gastar en nombre de owner.
    function allowance(address owner, address delegate) public view returns (uint) {
        return allowed[owner][delegate];
    }

    // Permite que msg.sender transfiera tokens de otra cuenta (owner) 
    // a un tercero (buyer) si ha sido aprobado previamente mediante approve.
    function transferFrom(address owner, address buyer, uint256 numTokens) public returns (bool) {
        require(numTokens <= balances[owner]);
        require(numTokens <= allowed[owner][msg.sender]);

        balances[owner] = balances[owner] - numTokens;
        allowed[owner][msg.sender] = allowed[owner][msg.sender] - numTokens;
        balances[buyer] = balances[buyer] + numTokens;
        emit Transfer(owner, buyer, numTokens);
        return true;
    }
}