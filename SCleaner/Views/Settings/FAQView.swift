import SwiftUI

/// Frequently Asked Questions screen
struct FAQView: View {
    @Environment(\.dismiss) private var dismiss

    private let faqs: [(question: String, answer: String)] = [
        (
            "Como o StorageCleaner encontra fotos duplicadas?",
            "Utilizamos um algoritmo de hash perceptual (dHash) que compara visualmente cada foto. Fotos com aparencia identica ou muito similar sao agrupadas automaticamente."
        ),
        (
            "Minhas fotos sao enviadas para algum servidor?",
            "Nao. Todo o processamento e feito localmente no seu dispositivo. Suas fotos nunca saem do seu iPhone."
        ),
        (
            "O que acontece quando excluo fotos?",
            "As fotos excluidas sao movidas para a pasta 'Apagados Recentemente' do iOS, onde ficam disponiveis por 30 dias antes da exclusao permanente."
        ),
        (
            "O que e a Lixeira do app?",
            "A Lixeira do app e um espaco interno onde arquivos de downloads excluidos ficam armazenados por 30 dias, permitindo restauracao antes da exclusao definitiva."
        ),
        (
            "Como funciona a assinatura?",
            "Oferecemos planos semanal e anual. Com a assinatura, voce tem acesso ilimitado a todas as funcionalidades de limpeza sem restricoes."
        ),
        (
            "Posso cancelar minha assinatura?",
            "Sim. Voce pode cancelar a qualquer momento nas Configuracoes do iPhone > Apple ID > Assinaturas. O acesso continua ate o final do periodo pago."
        ),
        (
            "O app funciona sem internet?",
            "Sim. O escaneamento e a exclusao funcionam offline. A conexao e necessaria apenas para compras e restauracao de assinaturas."
        )
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(faqs.indices, id: \.self) { index in
                    DisclosureGroup {
                        Text(faqs[index].answer)
                            .font(.system(size: 14))
                            .foregroundColor(ColorTokens.secondaryText)
                            .padding(.vertical, 4)
                    } label: {
                        Text(faqs[index].question)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ColorTokens.primaryText)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Perguntas Frequentes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundColor(ColorTokens.primaryBlue)
                }
            }
        }
    }
}
