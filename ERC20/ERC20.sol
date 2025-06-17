// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/ERC20.sol)

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";

// Es un contrato abstracto: no se puede desplegar directamente.
// Hereda de Context, IERC20 y IERC20Metadata,
// lo que obliga a implementar ciertas funciones.
abstract contract ERC20 is Context, IERC20, IERC20Metadata {
    // _balances: balance de cada dirección.
    mapping(address => uint256) private _balances;
    // _allowances: cuánto puede gastar un spender en nombre de un owner.
    mapping(address => mapping(address => uint256)) private _allowances;

    // _totalSupply: tokens existentes.
    // _name, _symbol: metadatos del token.
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    // Inicializa el nombre y símbolo al desplegar el token hijo.
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    // Consulta simple del estado.
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /// Consulta simple del estado.
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    // El msg.sender transfiere value tokens a to.
    // Permite que el usuario que llama a la función (msg.sender) 
    // transfiera tokens directamente a otro usuario (to).
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    // Devuelve cuántos tokens puede gastar spender de la cuenta de owner.
    // Es una función de consulta. 
    // Sirve para saber si alguien tiene autorización para gastar tokens y cuánto.
    function allowance(address owner, address spender)
        public
        view
        virtual
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    // approve: autoriza a spender a gastar value tokens del msg.sender.
    // Permite que el msg.sender autorice a otra dirección (spender) 
    // a gastar hasta value tokens en su nombre.
    function approve(address spender, uint256 value)
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    // Lógica de ERC20: quien llama puede mover tokens si fue aprobado por from.
    // Permite que una tercera persona (no el dueño) transfiera tokens 
    // en nombre del dueño, siempre que esté autorizado.
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    // Solo valida direcciones y delega la lógica a _update.
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        _update(from, to, value);
    }

    // Centraliza toda la lógica de transferencias, minting y burning.
    // Si from == 0, se está minting.
    // Si to == 0, se está burning.
    // Usa unchecked para ahorrar gas (seguro porque ya hay require previos).
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            require(
                fromBalance >= value,
                "ERC20: transfer amount exceeds balance"
            );
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    // Simplifican creación y destrucción de tokens.
    function _mint(address account, uint256 value) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        _update(account, address(0), value);
    }

    // _approve: fija el nuevo valor del allowance.
    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value,
        bool emitEvent
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    // _spendAllowance: resta lo usado si no es "ilimitado" (uint256.max).
    function _spendAllowance(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            require(currentAllowance >= value, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}
