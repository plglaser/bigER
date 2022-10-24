package org.big.erd.generator.pure;

import java.util.Collections;
import java.util.List;

import org.big.erd.entityRelationship.Attribute;
import org.big.erd.entityRelationship.AttributeType;
import org.big.erd.entityRelationship.DataType;
import org.big.erd.entityRelationship.Entity;
import org.big.erd.entityRelationship.Model;
import org.big.erd.entityRelationship.RelationEntity;
import org.big.erd.entityRelationship.Relationship;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.xtend2.lib.StringConcatenation;
import org.eclipse.xtext.generator.AbstractGenerator;
import org.eclipse.xtext.generator.IFileSystemAccess2;
import org.eclipse.xtext.generator.IGeneratorContext;
import org.eclipse.xtext.util.RuntimeIOException;
import org.eclipse.xtext.xbase.lib.Exceptions;

/**
 * Generates SQL in various dialects from the ER model.
 */
public class EntityRelationshipGenerator extends AbstractGenerator {

	@Override
	public void doGenerate(final Resource resource, final IFileSystemAccess2 fsa, final IGeneratorContext context) {
		final Model diagram = (Model) resource.getContents().get(0);
		if (diagram.getGenerateOption() == null || "off".equals(diagram.getGenerateOption().getGenerateOptionType().toString())) {
			return;
		}
		String diagramName = diagram.getName();
		final String fileName = (diagramName != null ? diagramName : "output") + ".sql";
		try {
			StringConcatenation fileContent = generateFileContent(diagram);
			fsa.generateFile(fileName, fileContent);
		} catch (final Throwable t) {
			if (t instanceof RuntimeIOException) {
				throw new Error("Could not generate file. Did you open a folder?");
			} else {
				throw Exceptions.sneakyThrow(t);
			}
		}
	}

	private StringConcatenation generateFileContent(final Model diagram) {
		StringConcatenation fileContent = new StringConcatenation();
		
		// entities
		for (final Entity entity : diagram.getEntities()) {
			if (!entity.isWeak()) {
				String table = this.toTable(entity);
				fileContent.append(table);
				fileContent.newLineIfNotEmpty();
			}
		}
		
		// weak relationships
		for (final Relationship relationship : diagram.getRelationships()) {
			if (relationship.isWeak()) {
				String weakTable = this.weakToTable(relationship);
				fileContent.append(weakTable);
				fileContent.newLineIfNotEmpty();
			}
		}
		
		// strong relationships
		for (final Relationship relationship : diagram.getRelationships()) {
			if (!relationship.isWeak()) {
				String table = this.toTable(relationship);
				fileContent.append(table);
				fileContent.newLineIfNotEmpty();
			}
		}
		
		return fileContent;
	}

	private String toTable(final Entity entity) {
		StringConcatenation tableContent = new StringConcatenation();
		startTable(tableContent, entity.getName());
		addAttributes(tableContent, entity.getAttributes());
		
		addPrimaryKeys(tableContent, this.primaryKey(entity));
		
		endTable(tableContent);
		return tableContent.toString();
	}

	private String toTable(final Relationship relationship) {
		Entity firstEntity = relationship.getFirst().getTarget();
		Attribute firstKey = null;
		if (firstEntity != null) {
			firstKey = this.primaryKey(firstEntity);
		}
		Entity secondEntity = relationship.getSecond().getTarget();
		Attribute secondKey = null;
		if (secondEntity != null) {
			secondKey = this.primaryKey(secondEntity);
		}
		RelationEntity third = relationship.getThird();
		Entity thirdEntity = null;
		if (third != null) {
			thirdEntity = third.getTarget();
		}
		Attribute thirdKey = null;
		if (thirdEntity != null) {
			thirdKey = this.primaryKey(thirdEntity);
		}
		
		StringConcatenation tableContent = new StringConcatenation();
		startTable(tableContent, relationship.getName());

		// foreign key
		addForeignKeyRefs(tableContent, firstEntity, secondEntity, thirdEntity);
		
		// attributes
		addAttributes(tableContent, relationship.getAttributes());
		
		// primary key
		addPrimaryKeys(tableContent, firstKey, secondKey, thirdKey);
		
		endTable(tableContent);
		return tableContent.toString();
	}

	private String weakToTable(final Relationship relationship) {
		final Entity strong = this.getStrongEntity(relationship);
		final Entity weak = this.getWeakEntity(relationship);
		
		StringConcatenation tableContent = new StringConcatenation();
		startTable(tableContent, weak.getName());

		// attributes
		addAttributes(tableContent, weak.getAttributes());
		addAttributes(tableContent, relationship.getAttributes());

		// primary key
		Attribute primaryKey = this.primaryKey(strong);
		addAttributes(tableContent, Collections.singletonList(primaryKey));
		addPrimaryKey(tableContent, false, this.partialKey(weak), primaryKey);

		// foreign key
		addForeignKey(tableContent, primaryKey, strong.getName());
		
		endTable(tableContent);
		return tableContent.toString();
	}

	private Attribute primaryKey(final Entity entity) {
		List<Attribute> attributes = entity.getAttributes();
		for (final Attribute attribute : attributes) {
			if (attribute.getType() == AttributeType.KEY) {
				return attribute;
			}
		}
		return attributes.get(0);
	}

	private Attribute partialKey(final Entity entity) {
		List<Attribute> attributes = entity.getAttributes();
		for (final Attribute attribute : attributes) {
			if (attribute.getType() == AttributeType.PARTIAL_KEY) {
				return attribute;
			}
		}
		return attributes.get(0);
	}

	private String transformDataType(final DataType dataType) {
		if ((dataType == null)) {
			return "CHAR(20)";
		}
		final String type = dataType.getType();
		int size = dataType.getSize();
		if (size != 0) {
			return type + "(" + Integer.valueOf(size) + ")";
		}
		return type;
	}

	private Entity getStrongEntity(final Relationship r) {
		if (r.getFirst().getTarget().isWeak()) {
			return r.getSecond().getTarget();
		} else {
			return r.getFirst().getTarget();
		}
	}

	private Entity getWeakEntity(final Relationship r) {
		if (r.getFirst().getTarget().isWeak()) {
			return r.getFirst().getTarget();
		} else {
			return r.getSecond().getTarget();
		}
	}

	private void startTable(StringConcatenation tableContent, String tableName) {
		tableContent.append("CREATE TABLE ");
		tableContent.append(tableName);
		tableContent.append(" (");
		tableContent.newLineIfNotEmpty();
	}

	private void endTable(StringConcatenation tableContent) {
		tableContent.append(");");
		tableContent.append("\n");
		tableContent.append("\n");
		tableContent.newLineIfNotEmpty();
	}

	private void addAttributes(StringConcatenation tableContent, List<Attribute> attributes) {
		for (final Attribute attribute : attributes) {
			if (attribute.getType() != AttributeType.DERIVED) {
				tableContent.append("\t");
				tableContent.append(attribute.getName());
				tableContent.append(" ");
				String transformedDataType = this.transformDataType(attribute.getDatatype());
				tableContent.append(transformedDataType);
				tableContent.append(",");
				tableContent.newLineIfNotEmpty();
			}
		}
	}

	private void addPrimaryKeys(StringConcatenation tableContent, Attribute... keys) {
		addPrimaryKey(tableContent, true, keys);
	}

	private void addPrimaryKey(StringConcatenation tableContent, boolean isLastContent, Attribute... keys) {
		tableContent.append("\t");
		tableContent.append("PRIMARY KEY (");
		
		boolean isFirst = true;
		for (Attribute key : keys) {
			if (key != null) {
				if (!isFirst) {
					tableContent.append(", ");
				} else {
					isFirst = false;
				}
				tableContent.append(key.getName());
			}
		}
		
		tableContent.append(")");
		if (!isLastContent) {
			tableContent.append(",");
		}
		tableContent.newLineIfNotEmpty();
	}

	private void addForeignKey(StringConcatenation tableContent, Attribute key, String refEntity) {
		addForeignKey(tableContent, true, key, refEntity);
	}

	private void addForeignKey(StringConcatenation tableContent, boolean isLastContent, Attribute key, String refEntity) {
		tableContent.append("\t");
		tableContent.append("FOREIGN KEY (");
		tableContent.append(key.getName());
		tableContent.append(") references ");
		tableContent.append(refEntity);
		tableContent.append(" ON DELETE CASCADE");
		if (!isLastContent) {
			tableContent.append(",");
		}
		tableContent.newLineIfNotEmpty();
	}

	private void addForeignKeyRefs(StringConcatenation tableContent, Entity... entities) {
		for (Entity entity : entities) {
			if (entity != null) {
				Attribute primaryKey = this.primaryKey(entity);
				tableContent.append("\t");
				tableContent.append(primaryKey.getName());
				tableContent.append(" ");
				String transformedDataType = this.transformDataType(primaryKey.getDatatype());
				tableContent.append(transformedDataType);
				tableContent.append(" references ");
				tableContent.append(entity.getName());
				tableContent.append("(");
				tableContent.append(primaryKey.getName());
				tableContent.append("),");
				tableContent.newLineIfNotEmpty();
			}
		}
	}
}
