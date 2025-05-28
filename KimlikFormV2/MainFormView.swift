import SwiftUI
import PencilKit
import UIKit

// MARK: - Supporting Models
struct SavedFormMetadata: Identifiable, Codable {
    let id: String
    let name: String
    let surname: String
    let tcNumber: String
    let savedDate: Date
    let userID: String
}

struct FormData {
    var name: String
    var surname: String
    var birthDate: Date
    var nationality: String
    var idNumber: String
    var birthPlace: String
    var idType: String
    var idSerialNumber: String
    var address: String
    var phone: String
    var fax: String
    var email: String
    var occupation: String
    var signature: UIImage?
    var frontImage: UIImage?
    var backImage: UIImage?
    var isPrintMode: Bool
}

enum ActiveSheet: Identifiable {
    case signature
    case printPreview
    case share
    case exportOptions
    
    var id: Int {
        hashValue
    }
}

class FormStorageManager: ObservableObject {
    static let shared = FormStorageManager()
    
    @Published var savedForms: [SavedFormMetadata] = []
    
    func searchByTCNumber(_ tcNumber: String) -> [SavedFormMetadata] {
        return savedForms.filter { $0.tcNumber == tcNumber }
    }
    
    func saveForm(_ formData: FormData) -> String {
        let metadata = SavedFormMetadata(
            id: UUID().uuidString,
            name: formData.name,
            surname: formData.surname,
            tcNumber: formData.idNumber,
            savedDate: Date(),
            userID: "kadireren"
        )
        
        savedForms.append(metadata)
        return metadata.id
    }
}

struct FormDetailView: View {
    let formID: String
    
    var body: some View {
        Text("Form Detayı: \(formID)")
            .navigationTitle("Form Detayı")
    }
}

// MARK: - Photo Capture View
struct PhotoCaptureView: View {
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var showingImagePicker = false
    @State private var selectedImageType: ImageType = .front
    @State private var showingFormView = false
    
    enum ImageType {
        case front, back
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Kimlik Fotoğrafı")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Kimliğinizin ön ve arka yüzünü çekin")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 30)
            
            // Fotoğraf Kartları
            VStack(spacing: 20) {
                // Ön yüz
                PhotoCard(
                    title: "Kimlik Ön Yüzü",
                    subtitle: "Fotoğraflı tarafı çekin",
                    image: frontImage,
                    systemIcon: "person.crop.rectangle",
                    color: .blue
                ) {
                    selectedImageType = .front
                    showingImagePicker = true
                }
                
                // Arka yüz
                PhotoCard(
                    title: "Kimlik Arka Yüzü",
                    subtitle: "TC numarasının bulunduğu tarafı çekin",
                    image: backImage,
                    systemIcon: "rectangle.and.text.magnifyingglass",
                    color: .green
                ) {
                    selectedImageType = .back
                    showingImagePicker = true
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Devam Et Butonu
            VStack(spacing: 15) {
                Button(action: {
                    showingFormView = true
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Form Doldurma Ekranına Geç")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canProceed ? Color.blue : Color.gray)
                    )
                }
                .disabled(!canProceed)
                
                if !canProceed {
                    Text("Devam etmek için her iki fotoğrafı da çekin")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: selectedImageType == .front ? $frontImage : $backImage)
        }
        .fullScreenCover(isPresented: $showingFormView) {
            NavigationView {
                IDFormView(frontImage: frontImage, backImage: backImage)
            }
        }
    }
    
    private var canProceed: Bool {
        frontImage != nil && backImage != nil
    }
}

struct PhotoCard: View {
    let title: String
    let subtitle: String
    let image: UIImage?
    let systemIcon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 15) {
                // Fotoğraf alanı - tek çerçeve
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 140) // Sabit yükseklik
                    
                    if let image = image {
                        // Fotoğraf varsa
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 120)
                            .cornerRadius(8)
                    } else {
                        // Fotoğraf yoksa - placeholder
                        VStack(spacing: 10) {
                            Image(systemName: systemIcon)
                                .font(.system(size: 30))
                                .foregroundColor(color)
                            
                            Text("Dokunarak Çek")
                                .font(.caption)
                                .foregroundColor(color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(color.opacity(0.15))
                                )
                        }
                    }
                }
                
                // Alt etiketler
                VStack(spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.editedImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Search Form View
struct SearchFormView: View {
    @State private var tcNumber = ""
    @State private var searchResults: [SavedFormMetadata] = []
    @State private var isSearching = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @FocusState private var isTCFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 25) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Form Arama")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("TC Kimlik No ile kayıtlı formları bulun")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 30)
            
            // Arama Alanı
            VStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TC Kimlik Numarası")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    TextField("12345678901", text: $tcNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($isTCFieldFocused)
                        .onChange(of: tcNumber) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            tcNumber = String(filtered.prefix(11))
                        }
                    
                    Text("11 haneli TC Kimlik Numaranızı girin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: searchForms) {
                    HStack {
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        
                        Image(systemName: "magnifyingglass")
                        Text(isSearching ? "Aranıyor..." : "Form Ara")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(tcNumber.count == 11 ? Color.blue : Color.gray)
                    )
                }
                .disabled(tcNumber.count != 11 || isSearching)
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func searchForms() {
        isSearching = true
        isTCFieldFocused = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            searchResults = FormStorageManager.shared.searchByTCNumber(tcNumber)
            isSearching = false
            
            if searchResults.isEmpty {
                alertMessage = "Bu TC Kimlik No ile kayıtlı form bulunamadı."
                showingAlert = true
            }
        }
    }
}

// MARK: - Main Menu View
struct MainMenuView: View {
    @State private var selectedOption: MenuOption?
    
    enum MenuOption {
        case newForm
        case searchForm
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // Logo/Başlık
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text("Kimlik Bilgileri")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Dijital Form Sistemi")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // Ana Seçenekler
                    VStack(spacing: 25) {
                        // Yeni Form Butonu - PhotoCaptureView'e yönlendir
                        NavigationLink(destination: PhotoCaptureView()) {
                            MenuOptionCard(
                                icon: "plus.circle.fill",
                                title: "Yeni Form",
                                subtitle: "Kimlik fotoğrafı çekerek başla",
                                color: .green
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Arama Butonu
                        NavigationLink(destination: SearchFormView()) {
                            MenuOptionCard(
                                icon: "magnifyingglass.circle.fill",
                                title: "Form Ara",
                                subtitle: "TC Kimlik No ile kayıtlı form ara",
                                color: .orange
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    
                    // Alt bilgi
                    VStack(spacing: 5) {
                        Text("KVKK Uyumlu • Güvenli Saklama")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Kullanıcı: kadireren")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct MenuOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 20) {
            // İkon
            Image(systemName: icon)
                .font(.system(size: 35))
                .foregroundColor(color)
                .frame(width: 60, height: 60)
                .background(Color.white.opacity(0.2))
                .cornerRadius(15)
            
            // Metin
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            // Ok işareti
            Image(systemName: "chevron.right")
                .font(.title3)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3), value: 1.0)
    }
}

// MARK: - IDFormView (Eski projeden alınmış ve güncellenmiş)
struct IDFormView: View {
    // Dışarıdan gelen fotoğraflar
    var frontImage: UIImage?
    var backImage: UIImage?
    
    // Form alanları
    @State private var fullName = ""
    @State private var birthDateText = ""
    @State private var nationality = "Türkiye"
    @State private var idNumber = ""
    @State private var birthPlace = ""
    @State private var idType = "Nüfus Cüzdanı"
    @State private var idSerialNumber = ""
    @State private var address = ""
    @State private var phoneText = ""
    @State private var fax = ""
    @State private var email = ""
    @State private var occupation = ""
    
    // Seçenekler
    @State private var isForeign = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    // İmza
    @State private var signature: UIImage?
    @State private var isPrintMode = false
    @State private var isGeneratingPDF = false
    
    // Sheet management
    @State private var activeSheet: ActiveSheet?
    @State private var shareItems: [Any] = []
    
    // Klavye optimizasyonu için
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isFieldFocused: Bool
    
    let idTypes = ["Nüfus Cüzdanı", "Ehliyet", "Pasaport"]
    
    init(frontImage: UIImage? = nil, backImage: UIImage? = nil) {
        self.frontImage = frontImage
        self.backImage = backImage
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 15) {
                    // Header
                    Text("Kimlik Bilgileri Formu")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    // Çekilen kimlik görselleri - EN ÜSTTE
                    if frontImage != nil || backImage != nil {
                        VStack(spacing: 15) {
                            Text("Kimlik Görselleri")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 20) {
                                // Ön yüz
                                VStack {
                                    Text("ÖN YÜZ")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    
                                    if let frontImage = frontImage {
                                        Image(uiImage: frontImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 100)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.blue, lineWidth: 1)
                                            )
                                    }
                                }
                                
                                // Arka yüz
                                VStack {
                                    Text("ARKA YÜZ")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    
                                    if let backImage = backImage {
                                        Image(uiImage: backImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 100)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.green, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.vertical, 10)
                    }
                    
                    // Form alanları
                    VStack(spacing: 12) {
                        // Kimlik Türü
                        HStack {
                            Text("Kimlik Türü*")
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)
                            Picker("", selection: $idType) {
                                ForEach(idTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Ad Soyad
                        OptimizedFormField(label: "Ad Soyad*", text: $fullName)
                        
                        // Doğum Tarihi
                        FormattedTextField(
                            label: "Doğum Tarihi* (GG/AA/YYYY)",
                            placeholder: "01/01/1990",
                            text: $birthDateText,
                            formatter: formatBirthDate,
                            keyboardType: .numberPad
                        )
                        
                        // TC Kimlik No
                        OptimizedFormField(label: "TC Kimlik No*", text: $idNumber, keyboardType: .numberPad)
                        
                        // Seri No
                        OptimizedFormField(label: "Seri No", text: $idSerialNumber)
                        
                        // Uyruk toggle
                        Toggle("Türk vatandaşı değilim", isOn: $isForeign)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                        
                        if isForeign {
                            OptimizedFormField(label: "Uyruk*", text: $nationality)
                            OptimizedFormField(label: "Doğum Yeri*", text: $birthPlace)
                        }
                        
                        // Telefon
                        FormattedTextField(
                            label: "Cep Telefonu* (05XX XXX XX XX)",
                            placeholder: "05XX XXX XX XX",
                            text: $phoneText,
                            formatter: formatPhoneNumber,
                            keyboardType: .numberPad
                        )
                        
                        OptimizedFormField(label: "E-posta*", text: $email, keyboardType: .emailAddress)
                        OptimizedFormField(label: "Meslek*", text: $occupation)
                        
                        // Adres
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Adres*")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            OptimizedTextEditor(text: $address)
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Fax
                        OptimizedFormField(label: "Fax", text: $fax, keyboardType: .phonePad)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    // İmza Bölümü
                    VStack(spacing: 10) {
                        Text("İMZA")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        // İmza seçenekleri
                        Picker("İmza Türü", selection: $isPrintMode) {
                            Text("Elektronik İmza").tag(false)
                            Text("Islak İmza").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        // İmza alanı
                        if isPrintMode {
                            // Islak imza için boş alan
                            ZStack {
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(height: 100)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                    )
                                
                                Text("Islak imza alanı")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .padding(.horizontal)
                        } else {
                            // Elektronik imza
                            Button(action: {
                                isFieldFocused = false
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    activeSheet = .signature
                                }
                            }) {
                                ZStack {
                                    Rectangle()
                                        .fill(signature == nil ? Color.blue.opacity(0.1) : Color.white)
                                        .frame(height: 100)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.blue, lineWidth: 1)
                                        )
                                    
                                    if let signature = signature {
                                        Image(uiImage: signature)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 98)
                                            .cornerRadius(7)
                                    } else {
                                        VStack(spacing: 4) {
                                            Image(systemName: "signature")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                            Text("İmzalamak için tıklayın")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                    
                    // Yasal Metin
                    Text("5549 sayılı Kanun kapsamında kimlik tespiti zorunludur.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    
                    // Butonlar
                    HStack(spacing: 15) {
                        Button("Kaydet") {
                            validateAndSaveForm()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isFormValid())
                        
                        Button(isGeneratingPDF ? "PDF Oluşturuluyor..." : "Kaydet/Paylaş") {
                            if !isGeneratingPDF && activeSheet == nil {
                                activeSheet = .exportOptions
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(isGeneratingPDF || activeSheet != nil)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .padding(.bottom, max(30, keyboardHeight))
            }
        }
        .navigationBarTitle("Bilgi Formu", displayMode: .inline)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .signature:
                SignatureView(signature: $signature) {
                    activeSheet = nil
                }
            case .exportOptions:
                ExportOptionsView(
                    onPDFExport: {
                        activeSheet = nil
                        // PDF export fonksiyonu burada çağrılabilir
                    },
                    onPrint: {
                        activeSheet = nil
                        // Print fonksiyonu burada çağrılabilir
                    },
                    onPreview: {
                        activeSheet = .printPreview
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )
            case .printPreview:
                PrintPreviewView(formData: prepareFormData()) {
                    activeSheet = nil
                }
            case .share:
                ActivityView(activityItems: shareItems) {
                    activeSheet = nil
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("Tamam"))
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatBirthDate(_ input: String) -> String {
        let numbers = input.filter { $0.isNumber }
        let trimmed = String(numbers.prefix(8))
        
        var formatted = ""
        for (index, char) in trimmed.enumerated() {
            if index == 2 || index == 4 {
                formatted += "/"
            }
            formatted += String(char)
        }
        return formatted
    }
    
    private func formatPhoneNumber(_ input: String) -> String {
        let numbers = input.filter { $0.isNumber }
        let trimmed = String(numbers.prefix(11))
        
        var formatted = ""
        for (index, char) in trimmed.enumerated() {
            switch index {
            case 0:
                formatted += "0"
                if char != "0" && !trimmed.isEmpty {
                    formatted += String(char)
                }
            case 1:
                if formatted.count == 1 {
                    formatted += "5"
                }
                if char != "5" && formatted.count == 2 {
                    formatted += String(char)
                }
            case 2, 3:
                formatted += String(char)
            case 4:
                formatted += " " + String(char)
            case 5, 6:
                formatted += String(char)
            case 7:
                formatted += " " + String(char)
            case 8:
                formatted += String(char)
            case 9:
                formatted += " " + String(char)
            case 10:
                formatted += String(char)
            default:
                break
            }
        }
        return formatted
    }
    
    private func isFormValid() -> Bool {
        let basicFields = !fullName.isEmpty && !birthDateText.isEmpty &&
                         !idNumber.isEmpty && !phoneText.isEmpty &&
                         !email.isEmpty && !occupation.isEmpty &&
                         !address.isEmpty
        
        let signatureValid = isPrintMode || signature != nil
        
        return basicFields && signatureValid
    }
    
    private func validateAndSaveForm() {
        alertTitle = "Başarılı"
        alertMessage = "Form kaydedildi."
        showingAlert = true
    }
    
    private func prepareFormData() -> FormData {
        let nameComponents = fullName.components(separatedBy: " ")
        let firstName = nameComponents.first ?? ""
        let lastName = nameComponents.dropFirst().joined(separator: " ")
        
        return FormData(
            name: firstName,
            surname: lastName,
            birthDate: parseBirthDate(birthDateText) ?? Date(),
            nationality: nationality,
            idNumber: idNumber,
            birthPlace: birthPlace,
            idType: idType,
            idSerialNumber: idSerialNumber,
            address: address,
            phone: phoneText,
            fax: fax,
            email: email,
            occupation: occupation,
            signature: isPrintMode ? nil : signature,
            frontImage: frontImage,
            backImage: backImage,
            isPrintMode: isPrintMode
        )
    }
    
    private func parseBirthDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.date(from: dateString)
    }
}

// MARK: - Supporting Views (Eski projeden alınmış)

struct OptimizedFormField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
            
            TextField("", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(keyboardType)
                .disableAutocorrection(true)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
        }
    }
}

struct FormattedTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let formatter: (String) -> String
    var keyboardType: UIKeyboardType = .default
    
    @State private var editingText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
            
            TextField(placeholder, text: $editingText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(keyboardType)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .focused($isFocused)
                .onAppear {
                    editingText = text
                }
                .onChange(of: editingText) { _, newValue in
                    if isFocused {
                        let formatted = formatter(newValue)
                        if formatted != editingText {
                            editingText = formatted
                        }
                        text = formatted
                    }
                }
                .onChange(of: text) { _, newValue in
                    if editingText != newValue {
                        editingText = newValue
                    }
                }
        }
    }
}

struct OptimizedTextEditor: View {
    @Binding var text: String
    
    var body: some View {
        TextEditor(text: $text)
            .disableAutocorrection(true)
            .autocapitalization(.words)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(configuration.isPressed ? Color.green.opacity(0.8) : Color.green)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SignatureView: View {
    @Binding var signature: UIImage?
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SignatureCanvasView(signature: $signature)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding()
                
                HStack(spacing: 20) {
                    Button("İptal") {
                        signature = nil
                        onDismiss()
                    }
                    .foregroundColor(.red)
                    
                    Button("Temizle") {
                        signature = nil
                    }
                    .foregroundColor(.orange)
                    
                    Button("Kaydet") {
                        onDismiss()
                    }
                    .foregroundColor(.blue)
                    .disabled(signature == nil)
                }
                .padding()
            }
            .navigationBarTitle("İmza Atın", displayMode: .inline)
        }
    }
}

struct SignatureCanvasView: UIViewRepresentable {
    @Binding var signature: UIImage?
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 2)
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        return canvasView
    }
    
    func updateUIView(_ canvasView: PKCanvasView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: SignatureCanvasView
        
        init(_ parent: SignatureCanvasView) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            
            if !drawing.bounds.isEmpty {
                let image = drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
                DispatchQueue.main.async {
                    self.parent.signature = image
                }
            } else {
                DispatchQueue.main.async {
                    self.parent.signature = nil
                }
            }
        }
    }
}

struct ExportOptionsView: View {
    let onPDFExport: () -> Void
    let onPrint: () -> Void
    let onPreview: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Kaydetme/Paylaşma Seçenekleri")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 15) {
                    Button("PDF Olarak Kaydet & Paylaş", action: onPDFExport)
                        .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Yazdır", action: onPrint)
                        .buttonStyle(SecondaryButtonStyle())
                    
                    Button("Önizleme Göster", action: onPreview)
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitle("Seçenekler", displayMode: .inline)
            .navigationBarItems(leading: Button("İptal", action: onCancel))
        }
    }
}

struct PrintPreviewView: View {
    var formData: FormData
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Form Önizlemesi")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("İçerik burada gösterilecek...")
                        .padding()
                }
                .padding()
            }
            .navigationBarTitle("Önizleme", displayMode: .inline)
            .navigationBarItems(leading: Button("Kapat", action: onDismiss))
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            onDismiss()
        }
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
