package br.com.relatorios.comum.seguranca;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;

import org.springframework.core.convert.converter.Converter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

/**
 * Lê <strong>duas</strong> claims aninhadas, e o Spring não traz conversor pronto para
 * nenhuma delas:
 *
 * <ul>
 *   <li><strong>Perfil</strong> — {@code realm_access.roles}. Conjunto fechado de três
 *       valores: {@code ADMINISTRADOR}, {@code GERENTE}, {@code RELATOR}.</li>
 *   <li><strong>Roles de Relatório</strong> — {@code resource_access.<client>.roles},
 *       porque são client roles de um client dedicado.</li>
 * </ul>
 *
 * <p><strong>O modo de falha aqui é autorização silenciosamente vazia, não exceção.</strong>
 * Um teste que apenas verifique "403 quando não autorizado" passa mesmo com este conversor
 * quebrado — é preciso o caso positivo, provando que a role certa concede.
 */
public class ConversorDeAuthorities implements Converter<Jwt, Collection<GrantedAuthority>> {

    private static final String PREFIXO = "ROLE_";

    private final String clientDasRoles;

    public ConversorDeAuthorities(String clientDasRoles) {
        this.clientDasRoles = clientDasRoles;
    }

    @Override
    public Collection<GrantedAuthority> convert(Jwt jwt) {
        List<GrantedAuthority> authorities = new ArrayList<>();
        rolesDoRealm(jwt).forEach(r -> authorities.add(new SimpleGrantedAuthority(PREFIXO + r)));
        rolesDoClient(jwt).forEach(r -> authorities.add(new SimpleGrantedAuthority(PREFIXO + r)));
        return authorities;
    }

    @SuppressWarnings("unchecked")
    private List<String> rolesDoRealm(Jwt jwt) {
        Map<String, Object> realm = jwt.getClaim("realm_access");
        if (realm == null) {
            return List.of();
        }
        Object roles = realm.get("roles");
        return roles instanceof List<?> lista ? (List<String>) lista : List.of();
    }

    @SuppressWarnings("unchecked")
    private List<String> rolesDoClient(Jwt jwt) {
        Map<String, Object> recursos = jwt.getClaim("resource_access");
        if (recursos == null) {
            return List.of();
        }
        Object cliente = recursos.get(clientDasRoles);
        if (!(cliente instanceof Map<?, ?> mapa)) {
            return List.of();
        }
        Object roles = mapa.get("roles");
        return roles instanceof List<?> lista ? (List<String>) lista : List.of();
    }
}
