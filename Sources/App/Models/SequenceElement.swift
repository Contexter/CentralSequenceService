import Fluent
import Vapor

final class SequenceElement: Model, Content {
    static let schema = "sequence_elements"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "element_type")
    var elementType: String
    
    @Field(key: "element_id")
    var elementId: Int
    
    @Field(key: "sequence_number")
    var sequenceNumber: Int
    
    @Field(key: "version_number")
    var versionNumber: Int
    
    init() { }
    
    init(id: UUID? = nil, elementType: String, elementId: Int, sequenceNumber: Int, versionNumber: Int) {
        self.id = id
        self.elementType = elementType
        self.elementId = elementId
        self.sequenceNumber = sequenceNumber
        self.versionNumber = versionNumber
    }
}
