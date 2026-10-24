import React, { useEffect, useState } from 'react';
import {
  SafeAreaView, View, Text, TextInput, TouchableOpacity,
  FlatList, Alert, StyleSheet, ScrollView, Share, ActivityIndicator
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { createClient } from '@supabase/supabase-js';

const URL = process.env.EXPO_PUBLIC_SUPABASE_URL || '';
const KEY = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || '';
const supabase = URL && KEY ? createClient(URL, KEY) : null;

export default function App() {
  const [session, setSession] = useState(null);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [title, setTitle] = useState('');
  const [code, setCode] = useState('');
  const [pastes, setPastes] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!supabase) return;
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: listener } = supabase.auth.onAuthStateChange((_event, s) => setSession(s));
    return () => listener.subscription.unsubscribe();
  }, []);

  async function auth(mode) {
    if (!supabase) {
      Alert.alert('Configuração necessária', 'Configure os secrets do Supabase no GitHub Actions.');
      return;
    }
    setLoading(true);
    const result = mode === 'signup'
      ? await supabase.auth.signUp({ email: email.trim(), password })
      : await supabase.auth.signInWithPassword({ email: email.trim(), password });
    setLoading(false);
    if (result.error) Alert.alert('Erro', result.error.message);
    else if (mode === 'signup' && !result.data.session)
      Alert.alert('Verifique seu e-mail', 'Confirme seu endereço de e-mail para entrar.');
  }

  async function loadPastes() {
    if (!supabase || !session) return;
    const { data, error } = await supabase.from('pastes')
      .select('*').order('created_at', { ascending: false });
    if (error) Alert.alert('Erro', error.message);
    else setPastes(data || []);
  }

  useEffect(() => { loadPastes(); }, [session]);

  async function createPaste() {
    if (!title.trim() || !code.trim()) {
      Alert.alert('Faltam dados', 'Informe um título e o código.');
      return;
    }
    setLoading(true);
    const { error } = await supabase.from('pastes').insert({
      user_id: session.user.id,
      title: title.trim(),
      content: code
    });
    setLoading(false);
    if (error) Alert.alert('Erro', error.message);
    else {
      setTitle('');
      setCode('');
      loadPastes();
      Alert.alert('Salvo', 'Seu paste foi criado.');
    }
  }

  async function sharePaste(item) {
    const { error } = await supabase.from('pastes')
      .update({ is_public: true }).eq('id', item.id);
    if (error) return Alert.alert('Erro', error.message);
    const base = process.env.EXPO_PUBLIC_PUBLIC_WEB_URL || '';
    const link = base ? `${base}?id=${item.id}` : `ID do paste: ${item.id}`;
    await Share.share({ message: `Meu paste no Lunex Paste: ${link}` });
    loadPastes();
  }

  async function deletePaste(id) {
    const { error } = await supabase.from('pastes').delete().eq('id', id);
    if (error) Alert.alert('Erro', error.message);
    else loadPastes();
  }

  return (
    <SafeAreaView style={s.page}>
      <StatusBar style="light" />
      <ScrollView contentContainerStyle={s.content}>
        <Text style={s.brand}>LUNEX<Text style={s.purple}> PASTE</Text></Text>
        <Text style={s.sub}>SEU CÓDIGO. ORGANIZADO.</Text>

        {!supabase ? (
          <View style={s.card}>
            <Text style={s.heading}>Configuração pendente</Text>
            <Text style={s.muted}>O app foi criado. Configure o projeto Supabase e os secrets do GitHub para habilitar login e armazenamento online.</Text>
          </View>
        ) : !session ? (
          <View style={s.card}>
            <Text style={s.heading}>Acesse sua conta</Text>
            <TextInput style={s.input} placeholder="E-mail" placeholderTextColor="#777" autoCapitalize="none" keyboardType="email-address" value={email} onChangeText={setEmail} />
            <TextInput style={s.input} placeholder="Senha (mínimo 6 caracteres)" placeholderTextColor="#777" secureTextEntry value={password} onChangeText={setPassword} />
            <TouchableOpacity style={s.button} onPress={() => auth('signin')} disabled={loading}>
              <Text style={s.buttonText}>{loading ? 'AGUARDE...' : 'ENTRAR'}</Text>
            </TouchableOpacity>
            <TouchableOpacity style={s.outline} onPress={() => auth('signup')}>
              <Text style={s.outlineText}>CRIAR CONTA</Text>
            </TouchableOpacity>
          </View>
        ) : (
          <>
            <View style={s.card}>
              <Text style={s.heading}>Novo paste</Text>
              <TextInput style={s.input} placeholder="Título do código" placeholderTextColor="#777" value={title} onChangeText={setTitle} />
              <TextInput style={[s.input, s.code]} placeholder="Cole seu código aqui..." placeholderTextColor="#777" value={code} onChangeText={setCode} multiline textAlignVertical="top" />
              <TouchableOpacity style={s.button} onPress={createPaste} disabled={loading}>
                <Text style={s.buttonText}>{loading ? 'SALVANDO...' : 'SALVAR PASTE'}</Text>
              </TouchableOpacity>
            </View>
            <View style={s.row}>
              <Text style={s.heading}>Meus pastes</Text>
              <TouchableOpacity onPress={loadPastes}><Text style={s.purple}>ATUALIZAR</Text></TouchableOpacity>
            </View>
            <FlatList
              data={pastes}
              scrollEnabled={false}
              keyExtractor={item => String(item.id)}
              ListEmptyComponent={<Text style={s.muted}>Nenhum paste ainda.</Text>}
              renderItem={({ item }) => (
                <View style={s.paste}>
                  <Text style={s.pasteTitle}>{item.title}</Text>
                  <Text style={s.muted} numberOfLines={2}>{item.content}</Text>
                  <View style={s.actions}>
                    <TouchableOpacity onPress={() => sharePaste(item)}><Text style={s.purple}>COMPARTILHAR</Text></TouchableOpacity>
                    <TouchableOpacity onPress={() => deletePaste(item.id)}><Text style={s.red}>EXCLUIR</Text></TouchableOpacity>
                  </View>
                </View>
              )}
            />
            <TouchableOpacity style={s.outline} onPress={() => supabase.auth.signOut()}>
              <Text style={s.outlineText}>SAIR DA CONTA</Text>
            </TouchableOpacity>
          </>
        )}
        <Text style={s.footer}>LUNEX PASTE • DESENVOLVIDO PARA CRIADORES</Text>
      </ScrollView>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  page: { flex: 1, backgroundColor: '#08080d' },
  content: { padding: 20, paddingTop: 35, paddingBottom: 45 },
  brand: { color: '#fff', fontSize: 32, fontWeight: '900', letterSpacing: 2 },
  purple: { color: '#a855f7', fontWeight: '800' },
  sub: { color: '#777', letterSpacing: 3, fontSize: 10, marginTop: 5, marginBottom: 25 },
  card: { backgroundColor: '#12121c', borderColor: '#292039', borderWidth: 1, borderRadius: 16, padding: 17, marginBottom: 22 },
  heading: { color: '#fff', fontSize: 18, fontWeight: '800', marginBottom: 13 },
  muted: { color: '#999', fontSize: 13, lineHeight: 20, marginBottom: 8 },
  input: { backgroundColor: '#090910', borderColor: '#30263f', borderWidth: 1, borderRadius: 10, color: '#fff', padding: 13, marginBottom: 12 },
  code: { minHeight: 145, fontFamily: 'monospace' },
  button: { backgroundColor: '#9333ea', padding: 15, borderRadius: 10, alignItems: 'center', marginTop: 4 },
  buttonText: { color: '#fff', fontWeight: '900', letterSpacing: 1 },
  outline: { borderColor: '#663399', borderWidth: 1, padding: 13, borderRadius: 10, alignItems: 'center', marginTop: 12 },
  outlineText: { color: '#c084fc', fontWeight: '800' },
  row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  paste: { backgroundColor: '#12121c', borderColor: '#292039', borderWidth: 1, borderRadius: 12, padding: 14, marginBottom: 12 },
  pasteTitle: { color: '#fff', fontSize: 16, fontWeight: '800', marginBottom: 8 },
  actions: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 10 },
  red: { color: '#fb7185', fontWeight: '800' },
  footer: { textAlign: 'center', color: '#555', fontSize: 9, letterSpacing: 1, marginTop: 30 }
});
