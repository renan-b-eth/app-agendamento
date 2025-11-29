import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart'; // O arquivo gerado pelo 'flutterfire configure'

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MeuAppFreela());
}

class MeuAppFreela extends StatelessWidget {
  const MeuAppFreela({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Freela Carga',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ==========================================
// 1. CONTROLE DE ACESSO (AuthGate)
// ==========================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          return const VerificadorDePerfil();
        }

        return const TelaLogin();
      },
    );
  }
}

// ==========================================
// 2. VERIFICADOR DE PERFIL
// ==========================================
class VerificadorDePerfil extends StatelessWidget {
  const VerificadorDePerfil({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usuarios').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final dados = snapshot.data!.data() as Map<String, dynamic>;
          final tipo = dados['tipo']; // 'patrao' ou 'trabalhador'

          if (tipo == 'patrao') {
            return const HomePatrao();
          } else {
            return const HomeTrabalhador();
          }
        }
        
        FirebaseAuth.instance.signOut();
        return const TelaLogin();
      },
    );
  }
}

// ==========================================
// 3. TELA DE LOGIN E CADASTRO
// ==========================================
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});
  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  bool _isLogin = true;
  bool _isLoading = false;
  
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  String _tipoSelecionado = 'trabalhador'; 

  Future<void> _enviar() async {
    if (_emailCtrl.text.isEmpty || _senhaCtrl.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _senhaCtrl.text.trim(),
        );
      } else {
        if (_nomeCtrl.text.isEmpty) throw Exception("Nome é obrigatório");

        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _senhaCtrl.text.trim(),
        );

        await FirebaseFirestore.instance.collection('usuarios').doc(credential.user!.uid).set({
          'nome': _nomeCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'tipo': _tipoSelecionado,
          'criado_em': Timestamp.now(),
        });
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Erro")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.local_shipping, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Text(
                _isLogin ? "Bem-vindo de volta" : "Criar Conta", 
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 30),
              
              if (!_isLogin) ...[
                TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: "Nome Completo", prefixIcon: Icon(Icons.person))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _tipoSelecionado,
                  decoration: const InputDecoration(labelText: "Eu sou...", prefixIcon: Icon(Icons.work)),
                  items: const [
                    DropdownMenuItem(value: 'trabalhador', child: Text("Trabalhador (Quero Freela)")),
                    DropdownMenuItem(value: 'patrao', child: Text("Patrão (Tenho Vagas)")),
                  ],
                  onChanged: (val) => setState(() => _tipoSelecionado = val!),
                ),
                const SizedBox(height: 10),
              ],

              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "E-mail", prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 10),
              TextField(controller: _senhaCtrl, decoration: const InputDecoration(labelText: "Senha", prefixIcon: Icon(Icons.lock)), obscureText: true),
              const SizedBox(height: 20),
              
              _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _enviar,
                    child: Text(_isLogin ? "ENTRAR" : "CADASTRAR", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
              
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? "Não tem conta? Crie agora" : "Já tem conta? Faça login"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. ÁREA DO PATRÃO (ADMIN)
// ==========================================
class HomePatrao extends StatelessWidget {
  const HomePatrao({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Minhas Vagas"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue[800],
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NovaVagaScreen())),
        label: const Text("Criar Vaga", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vagas')
            .orderBy('data_trabalho', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text("Você não postou nenhuma vaga."));

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              // CORREÇÃO AQUI: Extraindo os dados e forçando o tipo Map
              final doc = docs[index];
              final vaga = doc.data() as Map<String, dynamic>;
              final data = (vaga['data_trabalho'] as Timestamp).toDate();
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(vaga['local'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Row(children: [const Icon(Icons.calendar_today, size: 16), const SizedBox(width: 5), Text(DateFormat('dd/MM - HH:mm').format(data))]),
                      Row(children: [const Icon(Icons.attach_money, size: 16), const SizedBox(width: 5), Text("R\$ ${vaga['valor']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${vaga['preenchidas']}/${vaga['vagas_totais']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue[800])),
                        const Text("Preenchidas", style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// 5. TELA DE NOVA VAGA (PATRÃO)
// ==========================================
class NovaVagaScreen extends StatefulWidget {
  const NovaVagaScreen({super.key});
  @override
  State<NovaVagaScreen> createState() => _NovaVagaScreenState();
}

class _NovaVagaScreenState extends State<NovaVagaScreen> {
  final _localCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _qtdCtrl = TextEditingController();
  DateTime? _dataEscolhida;

  Future<void> _postar() async {
    if (_localCtrl.text.isEmpty || _valorCtrl.text.isEmpty || _qtdCtrl.text.isEmpty || _dataEscolhida == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos!")));
      return;
    }

    await FirebaseFirestore.instance.collection('vagas').add({
      'local': _localCtrl.text,
      'valor': double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? 0.0,
      'vagas_totais': int.tryParse(_qtdCtrl.text) ?? 1,
      'preenchidas': 0,
      'data_trabalho': Timestamp.fromDate(_dataEscolhida!),
      'criado_por': FirebaseAuth.instance.currentUser!.uid,
      'status': 'aberta',
      'descricao': 'Carga e Descarga padrão'
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nova Oportunidade")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _localCtrl, decoration: const InputDecoration(labelText: "Local (Endereço)", prefixIcon: Icon(Icons.pin_drop))),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: TextField(controller: _valorCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Valor (R\$)", prefixIcon: Icon(Icons.attach_money)))),
                const SizedBox(width: 15),
                Expanded(child: TextField(controller: _qtdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Qtd Pessoas", prefixIcon: Icon(Icons.group)))),
              ],
            ),
            const SizedBox(height: 15),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2025));
                if (date != null && mounted) {
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (time != null) {
                    setState(() => _dataEscolhida = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10), color: Colors.white),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      _dataEscolhida == null ? "Toque para agendar Data/Hora" : DateFormat('dd/MM/yyyy - HH:mm').format(_dataEscolhida!),
                      style: TextStyle(color: _dataEscolhida == null ? Colors.grey[600] : Colors.black, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _postar,
              child: const Text("PUBLICAR VAGA AGORA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. ÁREA DO TRABALHADOR
// ==========================================
class HomeTrabalhador extends StatelessWidget {
  const HomeTrabalhador({super.key});

  Future<void> _pegarVaga(BuildContext context, String vagaId, int preenchidas, int total) async {
    final user = FirebaseAuth.instance.currentUser!;
    
    // Referência do documento
    final vagaRef = FirebaseFirestore.instance.collection('vagas').doc(vagaId);
    
    // Verificar se já se candidatou
    final check = await vagaRef.collection('candidatos').doc(user.uid).get();
    
    if (check.exists) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você já aceitou este trabalho!")));
      return;
    }

    if (preenchidas < total) {
      // Atualiza contador e adiciona nome
      await vagaRef.update({'preenchidas': FieldValue.increment(1)});
      
      await vagaRef.collection('candidatos').doc(user.uid).set({
        'nome': user.displayName ?? 'Trabalhador',
        'email': user.email,
        'data_aceite': Timestamp.now()
      });

      if (context.mounted) {
        showDialog(
          context: context, 
          builder: (_) => AlertDialog(
            title: const Text("Sucesso!"), 
            content: const Text("Vaga garantida. O patrão recebeu seus dados."),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
          )
        );
      }
    } else {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vaga lotada! Tente outra.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Oportunidades"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vagas').orderBy('data_trabalho').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Nenhuma vaga disponível hoje."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              // CORREÇÃO: Pegamos o documento e convertemos os dados para MAP
              final doc = docs[index];
              final vaga = doc.data() as Map<String, dynamic>;
              
              final data = (vaga['data_trabalho'] as Timestamp).toDate();
              final ocupadas = vaga['preenchidas'];
              final total = vaga['vagas_totais'];
              final isFull = ocupadas >= total;
              
              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isFull ? Colors.grey[300] : Colors.green[50],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12))
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("R\$ ${vaga['valor']}", style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 20)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: Text("$ocupadas/$total vagas", style: const TextStyle(fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vaga['local'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.grey), const SizedBox(width: 5), Text(DateFormat('EEEE, dd/MM - HH:mm').format(data))]),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isFull ? null : () => _pegarVaga(context, doc.id, ocupadas, total),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFull ? Colors.grey : Colors.green[700],
                              ),
                              child: Text(isFull ? "ESGOTADO" : "ACEITAR TRABALHO"),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}